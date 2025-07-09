# PURPOSE: This is the root Terraform configuration file that defines the backend for state storage
# and invokes the k8s_cluster module using variables from a separate .tfvars file.

# 📦 Configure remote backend to store Terraform state in an S3 bucket
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.55"
    }
  }

  backend "s3" {
    bucket = "deema-terraform-states"       # S3 bucket to store tfstate
    key    = "k8s/terraform.tfstate"         # Path inside the bucket
    region = "us-west-1"                     # AWS region of the bucket
  }

  required_version = ">= 1.7.0"
}

# ☁️ Configure AWS provider
provider "aws" {
  region = var.region
}

# 🌐 Create the network infrastructure (VPC, subnets, etc.)
module "network" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "k8s-main-vpc"
  cidr = var.vpc_cidr

  azs            = var.azs
  public_subnets = var.public_subnets

  enable_nat_gateway   = false
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Project = "Polybot"
  }
}

# 🚀 Call the k8s_cluster module to provision the Kubernetes infrastructure
module "k8s_cluster" {
  source = "./modules/k8s-cluster"

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

  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.public_subnets
  acm_cert_arn       = var.acm_cert_arn
  s3_bucket_name     = var.s3_bucket_name
  dynamodb_table_arn = var.dynamodb_table_arn
  sqs_queue_arn      = var.sqs_queue_arn
}
