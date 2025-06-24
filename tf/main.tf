module "k8s_cluster" {
  source              = "./modules/k8s-cluster"
  aws_region          = var.aws_region
  key_name            = var.key_name
  vpc_id              = var.vpc_id
  subnet_id           = var.subnet_id

  ami_id              = var.ami_id
  worker_subnet_ids   = var.worker_subnet_ids
  worker_instance_type = var.worker_instance_type
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size

}


provider "aws" {
  region = var.aws_region
}


