variable "ami_id" {
  description = "AMI ID for worker nodes"
  type        = string
}

variable "worker_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "worker_subnet_ids" {
  description = "Subnets for the worker nodes"
  type        = list(string)
}
