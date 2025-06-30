terraform {
  backend "s3" {
    bucket = "deema-terraform-states"
    key    = "k8s/terraform.tfstate"
    region = "us-west-1"
  }
}

module "k8s_cluster" {
  source         = "./modules/k8s-cluster"

  # 🏷 Environment
  env            = "dev"
  region         = "us-west-1"
  ami_id         = "ami-014e30c8a36252ae5"
  instance_type  = "t3.medium"
  key_name       = "DeemaKey"
  vpc_cidr       = "10.0.0.0/16"
  azs            = ["us-west-1a", "us-west-1b"]

  # ⚙️ Auto Scaling Configuration
  desired_capacity = 0
  min_size         = 0
  max_size         = 3
}
