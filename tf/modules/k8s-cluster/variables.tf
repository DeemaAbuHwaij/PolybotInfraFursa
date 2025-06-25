variable "region" {
  description = "AWS region (e.g., us-west-1)"
  type        = string
}

variable "env" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to use for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "Instance type for EC2 instances (e.g., t3.medium)"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "azs" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "min_size" {
  description = "Minimum number of worker nodes in ASG"
  type        = number
}

variable "max_size" {
  description = "Maximum number of worker nodes in ASG"
  type        = number
}
