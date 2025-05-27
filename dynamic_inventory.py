#!/usr/bin/env python3

import boto3
import json
import sys

# Tag filter for selecting relevant EC2 instances
k8s_deployment_tag = {"Project": "capstone", "Function": "k8s_cluster"}

# Default group
default_group = "k8s_cluster"

# SSH config
ssh_user = "ubuntu"
ansible_params = "-o StrictHostKeyChecking=no"

def get_instances_by_tags(tags, region="eu-north-1"):
    ec2 = boto3.client("ec2", region_name=region)

    filters = [{"Name": "instance-state-name", "Values": ["running"]}]
    for key, value in tags.items():
        filters.append({"Name": f"tag:{key}", "Values": [value]})

    response = ec2.describe_instances(Filters=filters)
    instances = []

    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            public_ip = instance.get("PublicIpAddress")
            private_ip = instance.get("PrivateIpAddress")
            public_dns = instance.get("PublicDnsName")
            if not public_ip or not private_ip or not public_dns:
                continue

            tags_dict = {tag["Key"]: tag["Value"] for tag in instance.get("Tags", [])}
            name = tags_dict.get("Name", "Unnamed")
            role = tags_dict.get("Role")
            instances.append({
                "name": name,
                "ip": public_ip,
                "private_ip": private_ip,
                "public_dns": public_dns,
                "role": role,
            })

    return instances

def build_inventory(instances):
    inventory = {
        default_group: {
            "hosts": [],
            "vars": {
                "ansible_user": ssh_user,
                "ansible_ssh_common_args": ansible_params
            }
        },
        "_meta": {
            "hostvars": {}
        }
    }

    for inst in instances:
        ip = inst["ip"]
        role = inst["role"]

        inventory[default_group]["hosts"].append(ip)
        inventory["_meta"]["hostvars"][ip] = {}

        if role:
            if role not in inventory:
                inventory[role] = {"hosts": []}
            inventory[role]["hosts"].append(ip)

    return inventory

def show_endpoints(instances):
    print("Instance name, Private IP, Public IP, URL")
    for inst in instances:
        name = inst["name"]
        private_ip = inst["private_ip"]
        public_ip = inst["ip"]
        url = inst["public_dns"]
        print(f"{name}, {private_ip}, {public_ip}, {url}")

if __name__ == "__main__":
    if "--list" in sys.argv:
        instances = get_instances_by_tags(k8s_deployment_tag)
        inventory = build_inventory(instances)
        print(json.dumps(inventory, indent=2))
    elif "--host" in sys.argv:
        print(json.dumps({}))  # Required for Ansible dynamic inventory compatibility
    elif "--show-endpoints" in sys.argv:
        instances = get_instances_by_tags(k8s_deployment_tag)
        show_endpoints(instances)
    else:
        print("Usage: dynamic_inventory.py [--list | --host | --show-endpoints]")
        sys.exit(1)
