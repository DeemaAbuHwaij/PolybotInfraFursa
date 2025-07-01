# PURPOSE: This is the root Terraform configuration file that defines the backend for state storage
# and invokes the k8s_cluster module using variables from a separate .tfvars file.

# 📦 Configure remote backend to store Terraform state in an S3 bucket
terraform {
  backend "s3" {
    bucket = "deema-terraform-states"       # S3 bucket to store tfstate
    key    = "k8s/terraform.tfstate"         # Path inside the bucket
    region = "us-west-1"                     # AWS region of the bucket
  }
}

# 🚀 Call the k8s_cluster module to provision the Kubernetes infrastructure
module "k8s_cluster" {
  source = "./modules/k8s-cluster"

  # Values will be provided via region.us-west-1.tfvars
  env               = var.env
  region            = var.region
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  vpc_cidr          = var.vpc_cidr
  azs               = var.azs
  desired_capacity  = var.desired_capacity
  min_size          = var.min_size
  max_size          = var.max_size
}
