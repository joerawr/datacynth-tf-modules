variable "aws_profile" {
  type    = string
  default = null
}

variable "aws_region" {
  type    = string
  default = null
}

variable "name" {
  type    = string
  default = null
}

variable "vpc_cidr" {
  type    = string
  default = null
}

variable "az_count" {
  type    = number
  default = 1
}

variable "public_subnet_count" {
  type    = number
  default = 1
}

variable "private_subnet_count" {
  type    = number
  default = 1
}

variable "nat_gateway_count" {
  type    = number
  default = 0
}

variable "nat_instance_enabled" {
  type    = bool
  default = true
}

variable "nat_instance_type" {
  type    = string
  default = "t4g.micro"
}

variable "nat_instance_ami_filter" {
  type    = string
  default = "al2023-ami-2023.*-kernel-6.1-arm64"
}

variable "s3_gateway_enabled" {
  type    = bool
  default = true
}

variable "ipv6_enabled" {
  type    = bool
  default = false
}

variable "private_ingress_ports" {
  type    = list(number)
  default = [22, 443, 8080]
}
