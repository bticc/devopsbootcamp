# Provider configuration for AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Or whatever version you’re using
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"  # Locks to 2.5.x, latest as of now
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"  # Latest is fine, 3.x is common
    }
  }
}

# Variable for your dynamic IP (resolved externally)
variable "local_ip" {
  description = "Current external IP looked up via curl ifconfig.me "
  type        = string
}

# Variable for your dynamic IP (resolved externally)
variable "ansible_inventory_path" {
  description = "Location of the ansible inventory.ini file we output "
  type        = string
}

# Define the key name once
locals {
  workstation_key_name = "workstation-key"
}

# Define the security group name once
locals {
  workstation_sg_name = "workstation-ssh-sg"
}

# Data source to fetch the EC2 Instance Connect prefix list ID
data "aws_ec2_managed_prefix_list" "ec2_instance_connect" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.us-east-2.ec2-instance-connect"]
  }
}

# Data source to fetch the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm*-x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# Data source to get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source to pick any available subnet in the default VPC
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "us-east-2a"  # Pick one AZ; adjust if needed
}

# IAM role for EC2 (assuming EC2Admin is a pre-existing role; adjust if you need to create it)
data "aws_iam_role" "ec2_admin" {
  name = "EC2Admin"  # Must exist in AWS account
}

# Check for existing security group
data "aws_security_group" "existing_workstation_sg" {
  name   = local.workstation_sg_name
  vpc_id = data.aws_vpc.default.id
}

# Security group for SSH access via EC2 Instance Connect
resource "aws_security_group" "workstation_sg" {
  count       = length(data.aws_security_group.existing_workstation_sg.id) == 0 ? 1 : 0
  name        = local.workstation_sg_name
  description = "Allow SSH from EC2 Instance Connect and local IP"
  vpc_id      = data.aws_vpc.default.id

  # Rule for EC2 Instance Connect (us-east-2 IP range)
ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.ec2_instance_connect.id]
  }
  
  # Rule for your local devbox IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.local_ip}/32"]  # Replace with your IP (e.g., from `curl ifconfig.me`)
  }

  # Outbound rule (unchanged)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WorkstationSG"
  }
}

# Data source for existing key
data "aws_key_pair" "existing_workstation_key" {
  key_name           = local.workstation_key_name
  include_public_key = true
}

# Resource only if not exists
resource "aws_key_pair" "workstation_key" {
  count      = length(data.aws_key_pair.existing_workstation_key.key_name) == 0 ? 1 : 0
  key_name   = local.workstation_key_name
  public_key = file("~/.ssh/id_ed25519.pub")
}

# EC2 instance configuration
resource "aws_instance" "workstation" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnet.default.id
  associate_public_ip_address = true  # Auto-assign public IP
  vpc_security_group_ids      = [length(data.aws_security_group.existing_workstation_sg) > 0 ? data.aws_security_group.existing_workstation_sg.id : aws_security_group.workstation_sg[0].id]
  iam_instance_profile        = data.aws_iam_role.ec2_admin.name
  key_name                    = local.workstation_key_name

  tags = {
    Name = "Workstation"
  }
}

data "aws_region" "current" {}

output "region" {
  value = data.aws_region.current.name
}
# Output the public IP for easy access
output "workstation_instance_id" {
  value = aws_instance.workstation.id
}

output "workstation_public_ip" {
  value = aws_instance.workstation.public_ip
}

resource "local_file" "ansible_inventory" {
  content  = "[workstation]\n${aws_instance.workstation.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/id_ed25519"
  filename = var.ansible_inventory_path
}

resource "local_file" "aws_config" {
  content  = <<EOT
INSTANCE_ID=${aws_instance.workstation.id}
INSTANCE_REGION=${data.aws_region.current.name}
WORKSTATION_NAME=${aws_instance.workstation.tags.Name}
WORKSTATION_IP=${aws_instance.workstation.public_ip}
EOT
  filename = "../.instance"
  file_permission = "0600"  # Read/write for user only
}
