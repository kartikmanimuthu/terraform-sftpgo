variable "region" {
  description = "AWS Cloud Region"
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
}

variable "environment" {
  description = "Environment tag, e.g., prod, dev, staging."
}

variable "OU" {
  description = "Organization Unit"
}

variable "BU" {
  description = "Buisness Unit"
}

variable "PU" {
  description = "Project Unit"
}

variable "ec2_config" {
  description = "EC2 instance configuration"
  type = object({
    instance_type = string
    ami_id        = string
    volume_size   = number
    volume_type   = string
  })
}
