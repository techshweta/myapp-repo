variable "region" {
  default = "ap-south-1"
}

variable "instance_type" {
   default = "t3.micro"
}

variable "ssh_key_name" {
  description = "EC2 keypair name from AWS console"
  default     = "my-terraform-key"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "envs" {
  type    = list(string)
  default = ["dev", "uat", "prod"]
}
