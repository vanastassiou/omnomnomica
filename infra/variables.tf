variable "region" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "base_domain_name" {
  type = string
}

variable "ec2_deployer_public_key" {
  type = string
  description = "Contents of public key copied by Terraform build agent to compute instance to allow SSH connections"
}

variable "ec2_deployer_private_key" {
  type = string
  description = "Contents of private key offered by Terraform build agent to transfer files to compute instance over SSH"
}