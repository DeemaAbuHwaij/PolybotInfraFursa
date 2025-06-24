terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "k8s_cluster" {
  source     = "./modules/k8s-cluster"
  aws_region = var.aws_region
  key_name   = var.key_name
  vpc_id     = var.vpc_id
  subnet_id  = var.subnet_id
}
