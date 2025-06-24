terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket         = "deema-terraform-states"
    key            = "k8s/terraform.tfstate"
    region         = "us-west-1"
    encrypt        = true
    dynamodb_table = "deema-terraform-locks"
  }

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

# IAM role + instance profile
resource "aws_iam_role" "control_plane_role" {
  name = "deema-k8s-control-plane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "control_plane_profile" {
  name = "deema-k8s-control-plane-profile"
  role = aws_iam_role.control_plane_role.name
}

module "k8s_cluster" {
  source                      = "./modules/k8s-cluster"
  aws_region                  = var.aws_region
  key_name                    = var.key_name
  vpc_id                      = var.vpc_id
  subnet_id                   = var.subnet_id
  ami_id                      = var.ami_id
  worker_subnet_ids           = var.worker_subnet_ids
  worker_instance_type        = var.worker_instance_type
  desired_capacity            = var.desired_capacity
  min_size                    = var.min_size
  max_size                    = var.max_size
  control_plane_profile_name  = aws_iam_instance_profile.control_plane_profile.name
}