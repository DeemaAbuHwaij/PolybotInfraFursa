############################################
# PURPOSE: All Terraform variables for root and modules
# This includes network, EC2, IAM, LB, and app-specific infra
############################################

# ✅ Global Configuration
variable "region" {
  description = "AWS region (e.g., us-west-1)"
  type        = string
}

variable "env" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

# ✅ Networking
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for the instance"
  type        = string
}

variable "subnet_ids" {
  description = "List of Subnet IDs for control plane and ASG"
  type        = list(string)
}

# ✅ EC2 Configuration
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

# ✅ Auto Scaling Configuration
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

# ✅ Application / Integration (Bot + YOLO)
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
