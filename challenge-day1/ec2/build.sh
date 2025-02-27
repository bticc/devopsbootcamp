#!/bin/bash

# Get local external IP
LOCAL_IP=$(curl -s ifconfig.me)
ANSIBLE_INVENTORY_PATH="../../../ansible/inventory.ini"

# Handle commands
pushd "$(dirname "$0")" 

# Source instance file if it exists, silence errors if missing
source .instance 2>/dev/null || echo "No .instance file found, skipping instance deletion"

case $1 in
    "init")
        pushd terraform
        terraform init ${@:2} -var "local_ip=$LOCAL_IP" -var "ansible_inventory_path=$ANSIBLE_INVENTORY_PATH"
        popd
        ;;
    "validate")
        pushd terraform
        terraform validate ${@:2}
        popd
        ;;
    "plan")
        pushd terraform
        echo ANSIBLE_INVENTORY_PATH=$ANSIBLE_INVENTORY_PATH
        echo LOCAL_IP=$LOCAL_IP
        terraform plan ${@:2} -var "local_ip=$LOCAL_IP" -var "ansible_inventory_path=$ANSIBLE_INVENTORY_PATH"
        popd
        ;;
    "apply")
        pushd terraform
        terraform apply ${@:2} -var "local_ip=$LOCAL_IP" -var "ansible_inventory_path=$ANSIBLE_INVENTORY_PATH"
        popd
        ;;
    "config")
        pushd ansible
        ansible-playbook -i "$ANSIBLE_INVENTORY_PATH" playbook.yml
        popd
        ;;
    "destroy")
        if [ -n "$INSTANCE_ID" ]; then
            pushd terraform
            terraform destroy ${@:2} -var "local_ip=$LOCAL_IP" -var "ansible_inventory_path=$ANSIBLE_INVENTORY_PATH"
            popd
        else
            echo "No INSTANCE_ID or INSTANCE_REGION found in .instance—nothing to destroy."
        fi
        ;;
    "all")
        pushd terraform
        echo "Running 'terraform init'..."
        terraform init -var "local_ip=$LOCAL_IP" -var "ansible_inventory_path=$ANSIBLE_INVENTORY_PATH"
        echo "Running 'terraform validate'..."
        terraform validate -var "local_ip=$LOCAL_IP" -var "ansible_inventory_path=$ANSIBLE_INVENTORY_PATH"
        echo "Running 'terraform plan'..."
        terraform plan -var "local_ip=$LOCAL_IP" -var "ansible_inventory_path=$ANSIBLE_INVENTORY_PATH"
        echo "Running 'terraform apply'..."
        terraform apply -var "local_ip=$LOCAL_IP" -var "ansible_inventory_path=$ANSIBLE_INVENTORY_PATH"
        echo "Waiting for EC2 instance to be running..."
        popd
        source .instance 2>/dev/null \
            && aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region $INSTANCE_REGION --output-text \
            || echo "No .instance file found, skipping instance deletion" \
            && sleep 30
        pushd ansible
        echo "Running 'ansible-playbook'..."
        ansible-playbook -i "$ANSIBLE_INVENTORY_PATH" ansible/playbook.yml
        popd
        ;;
    *)
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  init         Initialize Terraform (optional: additional Terraform options)"
        echo "  validate     Validate Terraform config (optional: additional Terraform options)"
        echo "  plan         Generate and show Terraform plan (optional: additional Terraform options)"
        echo "  apply        Apply Terraform changes (optional: additional Terraform options)"
        echo "  config       Run Ansible playbook to configure the EC2 instance"
        echo "  destroy      Terminate the EC2 instance (requires INSTANCE_ID and INSTANCE_REGION in .instance)"
        echo "  all          Run full sequence: init, plan, apply, and config"
        echo ""
        echo "Environment:"
        echo "  Sourcing .instance for INSTANCE_ID and INSTANCE_REGION (if exists) for destroy command."
        echo "  LOCAL_IP dynamically fetched via ifconfig.me for security group rules."
        echo "  ANSIBLE_INVENTORY_PATH set to '../../../ansible/inventory.ini' for Terraform and Ansible."
        echo ""
        echo "Example:"
        echo "  $0 apply              # Apply Terraform changes"
        echo "  $0 destroy            # Terminate EC2 instance"
        echo "  $0 config             # Configure EC2 with Ansible"
        echo "  $0 all                # Full setup"
        echo ""
        echo "Note: Ensure AWS CLI is configured with appropriate credentials and region us-east-2."
        echo "      .instance should contain: INSTANCE_ID=<id> INSTANCE_REGION=us-east-2"
        exit 1
        ;;
esac
popd
