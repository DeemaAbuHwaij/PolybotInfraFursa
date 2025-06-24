# --- Terraform Backend Configuration ---
terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket         = "deema-terraform-states"     # ✅ change to your real S3 bucket name
    key            = "k8s/terraform.tfstate"       # ✅ the state file path in the bucket
    region         = "us-west-1"                   # ✅ your AWS region
    encrypt        = true
    dynamodb_table = "deema-terraform-locks"             # ✅ optional: for state locking
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --- AWS Provider ---
provider "aws" {
  region = var.aws_region
}

# --- Kubernetes Cluster Module ---
module "k8s_cluster" {
  source                = "./modules/k8s-cluster"
  aws_region            = var.aws_region
  key_name              = var.key_name
  vpc_id                = var.vpc_id
  subnet_id             = var.subnet_id

  ami_id                = var.ami_id
  worker_subnet_ids     = var.worker_subnet_ids
  worker_instance_type  = var.worker_instance_type
  desired_capacity      = var.desired_capacity
  min_size              = var.min_size
  max_size              = var.max_size
}
