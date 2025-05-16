This deploys kubernetes to AWS via terraform and ansible

Prerequisites:
`terraform
adsible
python3
boto3
aws congifure`

# Setup infra

In folder `terraform-infra`:
1. Create  terraform.tfvars:

```
aws_access_key           = "XXXXXXXX"
aws_secret_key           = "YYYYYYYY"
aws_region               = "eu-north-1"
azs                      = ["eu-north-1b", "eu-north-1c"]
vpc_cidr_block           = "10.0.0.0/16"
private_subnets          = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets           = ["10.0.3.0/24", "10.0.4.0/24"]

image_name               = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04*"  # Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
image_ami				         = "ami-04542995864e26699"
k8s_master_instance_type = "t3.medium"
k8s_worker_instance_type = "t3.micro"
ports                    = ["22", "80", "6443", "30001", "30002"]

# Tags to be set on all resources created
tags = {
  Owner    = "Username"
  Project  = "capstone"
  Function = "k8s_cluster"
}
```

2. Provision infra. Ssh key will be placed from ~/.ssh/id_rsa.pub
```
terraform init
terraform plan
terraform apply
```

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
`terraform destroy`



SOURCES used:
https://kubernetes.io/
https://github.com/torgeirl/kubernetes-playbooks
https://github.com/singhragvendra503/k8s_aws_terrafrom_ansible
