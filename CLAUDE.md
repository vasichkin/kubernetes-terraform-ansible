# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

Provisions a self-managed Kubernetes cluster (kubeadm, 1 master + N workers) on AWS: OpenTofu builds the VPC/EC2 infra, then Ansible installs and joins the cluster over SSH using dynamic inventory built from EC2 tags.

## Commands

All OpenTofu commands run from `terraform-infra/`; all Ansible commands run from the repo root. `dynamic_inventory.py` requires `boto3` — if it's not importable by whatever `python3` is first on `PATH`, activate the project venv first (`source .venv/bin/activate`; create it with `python3 -m venv .venv && .venv/bin/pip install boto3` if missing) before any `ansible`/`ansible-playbook` command below.

```bash
# Provision AWS infra
cd terraform-infra
tofu init -backend-config=backend.hcl
tofu plan
tofu apply
tofu destroy      # tear down

# Verify hosts are reachable before running playbooks
ansible k8s_cluster -i dynamic_inventory.py -m ping --ssh-common-args="-o StrictHostKeyChecking=no"

# Full cluster bring-up, in order (from repo root)
ansible-playbook -i dynamic_inventory.py ansible-playbooks/kube-dependencies.yml
ansible-playbook -i dynamic_inventory.py ansible-playbooks/master.yml
ansible-playbook -i dynamic_inventory.py ansible-playbooks/workers.yml
ansible-playbook -i dynamic_inventory.py ansible-playbooks/roles.yml
ansible-playbook -i dynamic_inventory.py ansible-playbooks/fetch_config.yml

# Or run them all via the umbrella playbook
ansible-playbook -i dynamic_inventory.py main_playbook.yml

# List discovered instances / show human-readable endpoints
python3 dynamic_inventory.py --list
python3 dynamic_inventory.py --show-endpoints

# Once cluster is up
kubectl --kubeconfig kubeconfigs/config get nodes
```

There is no test suite, linter, or CI config in this repo — validate OpenTofu changes with `tofu validate`/`tofu plan` and Ansible changes with `ansible-playbook --syntax-check` / `--check`.

## Architecture

**Two-phase deployment, glued together by `dynamic_inventory.py`:**

1. **`terraform-infra/`** — numbered `.tf` files applied in the order implied by their filename prefix (`0-provider.tf` … `11-output.tf`): provider/S3 backend → VPC (+ S3 VPC endpoint) → IGW → public/private subnets → NAT → route tables → SSH key pair → master/worker security groups → IAM policy/role/instance-profile → AMI lookup → ALB → master EC2 → worker EC2 (`count = var.k8s_worker_instance_count`) → outputs.
   - The master sits in the public subnet (`aws_subnet.public[0]`) with its own security group (`aws_security_group.master`, SSH + API server open to `0.0.0.0/0`). Workers sit in the **private** subnets (`aws_subnet.private[count.index % length(var.private_subnets)]`, round-robined across AZs) behind the NAT Gateway, with `aws_security_group.worker` allowing NodePort traffic *only* from the ALB's security group — workers have no direct internet-facing ingress.
   - Public HTTP access to apps running on the workers goes through the ALB (`7.4-alb.tf`): one target group + listener rule per entry in `var.alb_path_routes` (a `map(number)` of URL path pattern → backend NodePort, e.g. `{ "/grafana*" = 30300 }`), all registered against every worker instance. Add a new app by adding one line to that map — no other resource needs touching.
   - Every resource is tagged via `merge(var.tags, {Name = ..., Role = ...})`. `var.tags` has no default — it's required and supplied entirely via `terraform.tfvars`. The EC2 `Role` tag (`k8s_master` / `k8s_worker`) and the `tags.Project`/`tags.Function` values are load-bearing — `dynamic_inventory.py` filters EC2 instances by `{"Project": os.environ.get("K8S_TAG_PROJECT", "Experiment_kuber"), "Function": "k8s_cluster"}` and groups hosts by the `Role` tag. `tfvars.example` and `README.md` use `Project = "Experiment_kuber"` to match this default. If you use a different `Project` value in your tfvars, set the `K8S_TAG_PROJECT` env var to match before running `ansible`/`ansible-playbook`. If you change `var.tags` or the instance `Role` tags, update the filter/grouping in `dynamic_inventory.py` to match.
   - `7.3-ami.tf` resolves the AMI via a `data "aws_ami"` lookup filtered by `var.image_name` (most recent match) instead of a hardcoded AMI ID, so it never goes stale.
   - The `aws` provider has no `access_key`/`secret_key` args — it relies on the standard AWS credential chain (`AWS_PROFILE`, `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` env vars, or `~/.aws/credentials` via `aws configure`). Nothing in this repo carries AWS credentials.
   - Remote state is S3-backed (`0-provider.tf`). OpenTofu backend blocks cannot read variables/tfvars, so `bucket`/`region` are supplied via `-backend-config=backend.hcl` at `tofu init` time (copy from the checked-in `backend.hcl.example`; the real `backend.hcl` is gitignored like `terraform.tfvars`).
   - `7.2-instance-role.tf` sets `permissions_boundary` from the optional `var.permissions_boundary_arn` (default `null`); set it in `terraform.tfvars` only if your account requires IAM roles to carry a specific permissions boundary.
   - Secrets (`terraform.tfvars`, `*.tfstate`) and generated output (`kubeconfigs/`) are gitignored; `tfvars.example` is the template to copy.
   - SSH key material is not generated by OpenTofu — `6-ssh_key.tf` uploads the local `~/.ssh/id_rsa.pub` as the `k8s_key` key pair.

2. **`dynamic_inventory.py`** (repo root) — an executable Ansible dynamic inventory script (`--list`/`--host` contract) that calls `boto3` to find running EC2 instances matching the tag filter above, and groups them into `k8s_cluster` plus per-`Role` groups (e.g. `k8s_master`, `k8s_worker`) consumed directly by playbook `hosts:` selectors. `--show-endpoints` prints a human-readable name/IP/DNS table instead of inventory JSON. SSH connects as user `ubuntu`. Instances with no public IP (workers, now in private subnets) get a per-host `ansible_ssh_common_args` override adding `-o ProxyJump=ubuntu@<master_public_ip>`, so Ansible transparently reaches them through the master — no separate bastion needed.

3. **`ansible-playbooks/`** — run in this dependency order (also encoded in `main_playbook.yml`):
   - `kube-dependencies.yml`: runs on `all` — enforces Ubuntu 22.04, disables swap, installs/configures containerd, installs kubelet/kubeadm (pinned `1.36.*`) via the pkgs.k8s.io v1.36 repo, and installs kubectl on `k8s_master` only.
   - `master.yml`: runs on `k8s_master` — discovers the master's public IP/DNS (via `checkip.amazonaws.com` + `nslookup`), renders `kubeadm-config.yaml` (kubeadm.k8s.io/v1beta4) with the master's **private** IP as `controlPlaneEndpoint` (stable across stop/start, unlike the public IP, which is reassigned on every restart without an Elastic IP — see Notes) and private IP + public IP/DNS as certSANs, runs `kubeadm init`, sets up `~/.kube/config`, and applies the Flannel CNI manifest. Idempotent via `creates:` sentinel log files.
   - `workers.yml`: gets the join command from `k8s_master` via `set_fact`/`hostvars`, waits for port 6443, then runs `kubeadm join` on each `k8s_worker`.
   - `roles.yml`: applies a `ClusterRoleBinding` for `kube-scheduler` via `kubernetes.core.k8s`.
   - `fetch_config.yml`: fetches `admin.conf` from the master into `../kubeconfigs/config` and rewrites the `server:` field to the master's public IP so the kubeconfig works from outside the VPC.
   - `upgrade-cluster.yml` (opt-in, not part of `main_playbook.yml`/the bring-up order above): rolling in-place upgrade of an already-running cluster from v1.29 to v1.36. kubeadm only allows one minor version at a time, so it imports `upgrade-cluster-step.yml` seven times (once per intermediate minor, `vars: kube_version: "1.30"` … `"1.36"`), each import fully upgrading the control plane (repoint apt repo, `kubeadm upgrade apply`, drain/kubelet+kubectl/uncordon) before rolling workers one at a time (`serial: 1`; drain/uncordon delegated to the master, `kubeadm upgrade node`, kubelet). Idempotent/resumable via per-hop `creates:` sentinel logs. Run with `ansible-playbook -i dynamic_inventory.py ansible-playbooks/upgrade-cluster.yml`. The 1.29 starting-version assumption is asserted at the first hop — if the cluster isn't on 1.29.x it fails fast rather than attempting the wrong hops.

## Notes

- Assumes AWS region `eu-west-3` and Ubuntu 22.04 AMI images; changing region requires updating `terraform.tfvars` (and `backend.hcl`'s region only if you also move the state bucket — see below) and re-checking the hardcoded `checkip.amazonaws.com`/nslookup flow still resolves correctly.
- `var.ports` (default `[22, 6443]`) is master-only and opens to `0.0.0.0/0` — treat edits as security-relevant. Worker app exposure is controlled entirely by `var.alb_path_routes`, not `ports`.
- The ALB (`7.4-alb.tf`) is HTTP-only (port 80, no TLS) — add an HTTPS listener + ACM cert if you need TLS termination.
- Moving/replacing worker instances (subnet change, AMI refresh, etc.) forces EC2 replacement (`subnet_id` is not updatable in place) — the replaced worker will need `ansible-playbooks/workers.yml` re-run to rejoin the cluster.
- No Elastic IP is provisioned for the master, so its public IP changes on every stop/start. Since `controlPlaneEndpoint` uses the private IP, node readiness and joins are unaffected — but the apiserver cert's public-IP/DNS certSANs and the `kubeconfigs/config` produced by `fetch_config.yml` (server URL rewritten to the public IP) go stale on that event and need the cert SANs regenerated and `fetch_config.yml` re-run before external `kubectl` (from outside the VPC) will work again.
