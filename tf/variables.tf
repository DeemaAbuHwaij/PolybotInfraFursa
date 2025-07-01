# PURPOSE: This file defines all input variables used by the root Terraform module and passes them to the Kubernetes infrastructure module.

variable "env" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS region for the infrastructure"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to use for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for control plane and worker nodes"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair to use"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones to deploy in"
  type        = list(string)
}

variable "desired_capacity" {
  description = "Desired number of worker nodes in the ASG"
  type        = number
}

variable "min_size" {
  description = "Minimum number of worker nodes in the ASG"
  type        = number
}

variable "max_size" {
  description = "Maximum number of worker nodes in the ASG"
  type        = number
}
