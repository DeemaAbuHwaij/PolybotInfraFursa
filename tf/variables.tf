variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources in"
  default     = "us-west-1"
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair for SSH access"
}

variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet to launch the control plane into"
}
