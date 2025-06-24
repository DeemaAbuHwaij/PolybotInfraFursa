aws_region = "us-west-1"
key_name   = "DeemaKey"
vpc_id     = "vpc-0a2647ad96e5c854b"
subnet_id  = "subnet-00b178dd39291db6a"

# Worker node configuration
ami_id              = "ami-014e30c8a36252ae5"  # ✅ Ubuntu 22.04 in us-west-1
worker_instance_type = "t3.medium"
desired_capacity    = 2
min_size            = 1
max_size            = 3
worker_subnet_ids   = ["subnet-00b178dd39291db6a"]  # ✅ You can add more subnets if needed
