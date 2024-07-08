locals {
  environment = var.environment

  project_name = "${var.OU}-${var.BU}-${var.PU}"

  tags = merge(var.tags, {
    Terraform    = "true"
    OU           = var.OU
    BU           = var.BU
    PU           = var.PU
    project_name = local.project_name
    environment  = local.environment
  })
}



# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Get public subnets from default VPC in the first available AZ
data "aws_subnet" "selected" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}


# Get current AWS region
data "aws_region" "current" {}



# Create random string for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create S3 bucket
resource "aws_s3_bucket" "sftp_bucket" {
  bucket = lower("${local.project_name}-sftp-${random_string.suffix.result}")
}


# Create IAM user
resource "aws_iam_user" "sftp_user" {
  name = "${local.project_name}-sftp-user-${random_string.suffix.result}"
}

# Create IAM user access key
resource "aws_iam_access_key" "sftp_user_key" {
  user = aws_iam_user.sftp_user.name
}

# Create IAM policy for S3 bucket access
resource "aws_iam_user_policy" "sftp_user_policy" {
  name = "${local.project_name}-sftp-s3-access-policy"
  user = aws_iam_user.sftp_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          aws_s3_bucket.sftp_bucket.arn,
          "${aws_s3_bucket.sftp_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Store access key in Parameter Store
resource "aws_ssm_parameter" "access_key" {
  name  = "/${local.project_name}/sftp/access-key"
  type  = "SecureString"
  value = aws_iam_access_key.sftp_user_key.id
}

# Store secret key in Parameter Store
resource "aws_ssm_parameter" "secret_key" {
  name  = "/${local.project_name}/sftp/secret-key"
  type  = "SecureString"
  value = aws_iam_access_key.sftp_user_key.secret
}



# Create IAM role for EC2 SSM access
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${local.project_name}-ec2-ssm-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach SSM policy to the role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2_ssm_role.name
}

# Create IAM instance profile
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${local.project_name}-ec2-ssm-profile-${random_string.suffix.result}"
  role = aws_iam_role.ec2_ssm_role.name
}

# Modify the IAM role for S3 access
resource "aws_iam_role" "s3_access_role" {
  name = "${local.project_name}-s3-access-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_ssm_role.arn
        }
      }
    ]
  })
}

# Attach S3 access policy to the role
resource "aws_iam_role_policy" "s3_access_policy" {
  name = "${local.project_name}-s3-access-policy"
  role = aws_iam_role.s3_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          aws_s3_bucket.sftp_bucket.arn,
          "${aws_s3_bucket.sftp_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach SSM policy to the role
resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.s3_access_role.name
}

# Create IAM instance profile for S3 access
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "${local.project_name}-ec2-s3-profile-${random_string.suffix.result}"
  role = aws_iam_role.s3_access_role.name
}

# Add a policy to allow the EC2 instance to assume the S3 access role
resource "aws_iam_role_policy" "assume_s3_role_policy" {
  name = "${local.project_name}-assume-s3-role-policy"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.s3_access_role.arn
      }
    ]
  })
}

# Modify Security Group to use the default VPC
resource "aws_security_group" "ec2_sg" {
  name        = "${local.project_name}-ec2-sg-${random_string.suffix.result}"
  description = "Security group for EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port   = 8080
  #   to_port     = 8080
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.project_name}-ec2-sg-${random_string.suffix.result}"
  })
}

# Modify EC2 instance to use the selected public subnet and the S3 access role
resource "aws_instance" "ubuntu_instance" {
  ami           = var.ec2_config.ami_id
  instance_type = var.ec2_config.instance_type
  subnet_id     = data.aws_subnet.selected.id

  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_s3_profile.name

  root_block_device {
    volume_size = var.ec2_config.volume_size
    volume_type = var.ec2_config.volume_type
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo snap install amazon-ssm-agent --classic
              sudo systemctl enable amazon-ssm-agent
              sudo systemctl start amazon-ssm-agent
              EOF

  tags = merge(local.tags, {
    Name = "${local.project_name}-ec2-${random_string.suffix.result}"
  })
}

# Create Elastic IP
resource "aws_eip" "ubuntu_eip" {
  instance = aws_instance.ubuntu_instance.id
  domain   = "vpc"

  tags = merge(local.tags, {
    Name = "${local.project_name}-eip-${random_string.suffix.result}"
  })
}

# Add an explicit dependency on the EC2 instance
resource "aws_eip_association" "ubuntu_eip_assoc" {
  instance_id   = aws_instance.ubuntu_instance.id
  allocation_id = aws_eip.ubuntu_eip.id
}


# ==================================================================================================
#                                             Ansible
# ==================================================================================================

# Create S3 bucket for Ansible SSM
resource "aws_s3_bucket" "ansible_ssm_bucket" {
  bucket = lower("${local.project_name}-ansible-ssm-${random_string.suffix.result}")
}


# Modify the wait_for_instance resource to depend on the EIP association
resource "null_resource" "wait_for_instance" {
  depends_on = [aws_instance.ubuntu_instance, aws_eip_association.ubuntu_eip_assoc]

  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.ubuntu_instance.id} && sleep 60"
  }
}

# Install Ansible role
resource "null_resource" "install_ansible_role" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "ansible-galaxy role install geerlingguy.docker,7.1.0"
  }
}

# Run Ansible playbook install
resource "null_resource" "run_ansible_install" {
  depends_on = [aws_instance.ubuntu_instance, aws_s3_bucket.ansible_ssm_bucket, null_resource.wait_for_instance, null_resource.install_ansible_role]

  provisioner "local-exec" {
    command     = <<-EOT
      ansible-playbook -i '${aws_instance.ubuntu_instance.id},' \
      -e "ansible_aws_ssm_bucket_name=${aws_s3_bucket.ansible_ssm_bucket.id}" \
      -e "ansible_aws_ssm_region=${data.aws_region.current.name}" \
      playbook-install.yml
    EOT
    working_dir = "${path.module}/ansible"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      ANSIBLE_HOST_KEY_CHECKING           = "False"
      OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES"
    }
  }
}


# Run Ansible playbook deploy
resource "null_resource" "run_ansible_deploy" {
  depends_on = [aws_instance.ubuntu_instance, aws_s3_bucket.ansible_ssm_bucket, null_resource.wait_for_instance, null_resource.install_ansible_role, null_resource.run_ansible_install]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = <<-EOT
      ansible-playbook -i '${aws_instance.ubuntu_instance.id},' \
      -e "ansible_aws_ssm_bucket_name=${aws_s3_bucket.ansible_ssm_bucket.id}" \
      -e "ansible_aws_ssm_region=${data.aws_region.current.name}" \
      playbook-deploy.yml
    EOT
    working_dir = "${path.module}/ansible"
    interpreter = ["/bin/bash", "-c"]
    environment = {
      ANSIBLE_HOST_KEY_CHECKING           = "False"
      OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES"
    }
  }
}
