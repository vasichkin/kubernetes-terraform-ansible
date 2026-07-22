## Self-managed kubernetes deployment in mixed environment
Idea: I love idea of managing kubernetes cluster myself. It's much cheaper and don't have limitations EKS has. Also, I believe beiung cloud-agnostic is important feature in kubernetes wolrd. So, this project is implementation of kubernetes setup in mixed environmet. I'm trying to get the best out of both worlds (cloud and kuber)

This project deploys self-managed (via kubeadm) kubernetes cluster to AWS EC2 instances vusingia OpenTofu (or terraform) and ansible. Also, cluster is deployed in private VPC, making it mode secure. Public connections are routed via AWS LoadBalancers.

## Architecture

```text
┌────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                  │
└───────────┬─────────────────────────────────────┬──────────────────────┘
            │ :6443, 22 (admin access)            │ :80 (Public access)
            ▼                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│  VPC 10.0.0.0/16  (eu-west-3)                                          │
│                                                                        │
│  ┌────────────────────── Public subnets (2 AZ) ──────────────────────┐ │
│  │                                                                   │ │
│  │   ┌─────────────────┐          ┌────────────────────────────┐     │ │
│  │   │   k8s_master    │          │       ALB  (k8s-alb)       │     │ │
│  │   │  SG: 22, 6443   │          │   SG: 80  (0.0.0.0/0)      │     │ │
│  │   │  public IP      │          │   path routing:            │     │ │
│  │   │  control-plane  │          │   /grafana* -> tg-grafana  │     │ │
│  │   │  SSH jump host  │          │   /app*     -> tg-app      │     │ │
│  │   └────────┬────────┘          └──────────────┬─────────────┘     │ │
│  │            │                                  │                   │ │
│  │      ┌─────┴─────┐                            │ NodePort          │ │
│  │      │ NAT GW+EIP│                            │ (30300 / 30080)   │ │
│  │      └─────┬─────┘                            │                   │ │
│  └────────────┼──────────────────────────────────┼───────────────────┘ │
│               │ egress only                      │                     │
│  ┌────────────┼───────── Private subnets (2 AZ) ─┼────────────────────┐│
│  │            ▼                                   ▼                   ││
│  │    ┌────────────────┐               ┌────────────────┐             ││
│  │    │  k8s_worker-0  │               │  k8s_worker-1  │             ││
│  │    │ SG: NodePort   │               │ SG: NodePort   │             ││
│  │    │ from ALB only  │               │ from ALB only  │             ││
│  │    │ no public IP   │               │ no public IP   │             ││
│  │    └────────────────┘               └────────────────┘             ││
│  │            ▲ SSH via ProxyJump through master (Ansible only)       ││
│  └────────────────────────────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────────────────┘
```
Why? It's sandbox. It used for testing infra and new features. It simulates real cluster. Private network secures cluster from internet. Using ALB allows usage of cloud features as well manage public resources access. Admin access should be limited, ofcourse. 
Master node should also be in private VPC.


## Setup
Prerequisites:
`opentofu (tofu)
adsible
python3
aws congifure`

`dynamic_inventory.py` needs `boto3`. If your `python3` is a Homebrew/system install, `pip install boto3` will likely fail with "externally-managed-environment" — use a venv instead:
```
python3 -m venv .venv
.venv/bin/pip install boto3
source .venv/bin/activate   # do this before any ansible/ansible-playbook command below
```

# Setup infra

AWS credentials are picked up from your system (`aws configure`, `AWS_PROFILE`, or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` env vars) — they are not stored in this project.

In folder `terraform-infra`:
1. Create  terraform.tfvars:

```
aws_region               = "eu-west-3"
azs                      = ["eu-west-3b", "eu-west-3c"]
vpc_cidr_block           = "10.0.0.0/16"
private_subnets          = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets           = ["10.0.3.0/24", "10.0.4.0/24"]

image_name               = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04*"  # Ubuntu Server 22.04 LTS (HVM), SSD Volume Type; latest matching AMI is resolved automatically
k8s_master_instance_type = "t3.medium"
k8s_worker_instance_type = "t3.micro"

# Master-only ports (SSH + Kubernetes API); worker app ports are exposed via the ALB below, not this list
ports = [22, 6443]

# ALB path-based routing: URL path pattern -> backend NodePort on the workers
alb_path_routes = {
  "/grafana*" = 30300
  "/app*"     = 30080
}

# Tags to be set on all resources created
tags = {
  Owner    = "Username"
  Project  = "KuberCluster"
  Function = "k8s_cluster"
}
```

2. Create the S3 bucket for OpenTofu state (one-time, must exist before `tofu init` — the backend can't create its own bucket):

```
aws s3api create-bucket \
  --bucket capstone-terraform-state \
  --region eu-west-3 \
  --create-bucket-configuration LocationConstraint=eu-west-3

aws s3api put-bucket-versioning \
  --bucket capstone-terraform-state \
  --versioning-configuration Status=Enabled
```

3. Create backend.hcl (copy from `backend.hcl.example`) with your state bucket:

```
bucket = "capstone-terraform-state"
region = "eu-west-3"
```

4. Provision infra. Ssh key will be placed from ~/.ssh/id_rsa.pub
```
tofu init -backend-config=backend.hcl
tofu plan
tofu apply
```

Workers are provisioned in private subnets behind a NAT Gateway and are only reachable from the internet through the ALB (`alb_dns_name` output); Ansible reaches them for setup by SSH-jumping through the master automatically. Apps are exposed publicly via the path routes configured in `alb_path_routes` — add an entry there for each app's NodePort.

# Install Kubernetes
In project root folder:
1. Check deployed hosts are accessible
```ansible k8s_cluster -i ../dynamic_inventory.py -m ping --ssh-common-args="-o StrictHostKeyChecking=no"```

2. `ansible-playbook -i dynamic_inventory.py ansible-playbooks/kube-dependencies.yml`
3. `ansible-playbook -i dynamic_inventory.py ansible-playbooks/master.yml`
4. `ansible-playbook -i dynamic_inventory.py ansible-playbooks/workers.yml`
6. `ansible-playbook -i dynamic_inventory.py ansible-playbooks/fetch_config.yml`
7. Check cluster accessible `kubectl --kubeconfig kubeconfigs/config get nodes`
8. Copy kubeconfigs/config to ~/.kube/config and you are done.


# Delete
`tofu destroy`



SOURCES used:
https://kubernetes.io/
https://github.com/torgeirl/kubernetes-playbooks
https://github.com/singhragvendra503/k8s_aws_terrafrom_ansible
