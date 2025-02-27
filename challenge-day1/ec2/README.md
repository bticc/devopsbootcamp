#### `devopsbootcamp/challenge-day1/ec2/README.md`
```markdown
# EC2 Workstation Setup (Extra Credit)

Sets up an Amazon Linux 2023 t2.micro in us-east-2 with Terraform and Ansible.

## Files
- `tarraform/main.tf`: Terraform script for EC2, security group, and key pair.
- `ansible/playbook.yml`: Configures user, sshd, and installs necessary tools on EC2.
- `../build.sh`: 
## Usage
```build.sh (init|validate|plan|apply|config|all|destroy|help)

```Usage: build.sh [command] [options]

Commands:
  `init`         Initialize Terraform (optional: additional Terraform options)
  `validate`     Validate Terraform config (optional: additional Terraform options)
  `plan`         Generate and show Terraform plan (optional: additional Terraform options)
  `apply`        Apply Terraform changes (optional: additional Terraform options)
  `config`       Run Ansible playbook to configure the EC2 instance
  `destroy`      Terminate the EC2 instance (requires INSTANCE_ID in .instance)
  `all`          Run full sequence: init, plan, apply, and config

Environment:
  Sourcing .instance for INSTANCE_ID (if exists) for destroy command.
  LOCAL_IP dynamically fetched via ifconfig.me for security group rules.

