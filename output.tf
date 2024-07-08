# Output bucket name
output "s3_bucket_name" {
  value = aws_s3_bucket.sftp_bucket.id
}


# Output IAM user name
output "iam_user_name" {
  value = aws_iam_user.sftp_user.name
}

# Output Parameter Store paths
output "access_key_param_path" {
  value = aws_ssm_parameter.access_key.name
}

output "secret_key_param_path" {
  value = aws_ssm_parameter.secret_key.name
}




# Update the output to use the Elastic IP
output "ec2_public_ip" {
  value = aws_eip.ubuntu_eip.public_ip
}

# New outputs
output "ec2_instance_id" {
  value = aws_instance.ubuntu_instance.id
}

output "elastic_ip" {
  value = aws_eip.ubuntu_eip.public_ip
}

# Add new outputs for VPC and Subnet IDs
output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "public_subnet_id" {
  value = data.aws_subnet.selected.id
}

output "iam_role_name" {
  value = aws_iam_role.s3_access_role.name
}

output "iam_role_arn" {
  value = aws_iam_role.s3_access_role.arn
}

output "region" {
  value = data.aws_region.current.name
}



# Output Ansible SSM bucket name
output "ansible_ssm_bucket_name" {
  value = aws_s3_bucket.ansible_ssm_bucket.id
}
