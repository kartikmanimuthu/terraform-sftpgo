OU          = "acme"
BU          = "infra"
PU          = "sftp"
environment = "prod"

region = "ap-south-1"

tags = {
  schedule = "office-hours-9am-7pm-mon-fri"
}

ec2_config = {
  instance_type = "t2.micro"
  ami_id        = "ami-07083120e701c3d78"
  volume_size   = 100
  volume_type   = "gp2"
}
