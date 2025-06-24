variable "aws_region" {
  type = string
}

variable "key_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "worker_subnet_ids" {
  type = list(string)
}

variable "desired_capacity" {
  type = number
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "worker_instance_type" {
  type = string
}

variable "use_existing_iam" {
  description = "Use existing IAM instance profile"
  type        = bool
  default     = false
}
