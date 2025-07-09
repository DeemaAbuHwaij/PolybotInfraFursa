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


variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "acm_cert_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name used for uploading images from the bot"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table used by the YOLO service"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue used by the YOLO service"
  type        = string
}
