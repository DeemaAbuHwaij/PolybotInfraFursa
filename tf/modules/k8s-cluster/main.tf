# PURPOSE: This Terraform file provisions all AWS infrastructure resources needed for a Kubernetes cluster,
# including VPC, subnets, security groups, IAM roles, EC2 control plane instance, and worker Auto Scaling Group.

# ✅ VPC definition
resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "deema-k8s-vpc-${var.env}"
  }
}

# ✅ Internet Gateway for public access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "deema-igw-${var.env}"
  }
}

# ✅ IAM Role for control plane EC2 instance
resource "aws_iam_role" "control_plane_role" {
  name = "deema-k8s-control-plane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# ✅ Attach required policies to IAM role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "secrets_manager_access" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# ✅ IAM instance profiles for EC2 instances
resource "aws_iam_instance_profile" "control_plane_profile" {
  name = "deema-k8s-control-plane-profile"
  role = aws_iam_role.control_plane_role.name
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "deema-k8s-worker-profile"
  role = aws_iam_role.control_plane_role.name
}

# ✅ Public subnets across multiple availability zones
resource "aws_subnet" "public_subnets" {
  count             = 2
  vpc_id            = aws_vpc.k8s_vpc.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "deema-public-subnet-${count.index}-${var.env}"
  }
}

# ✅ Route table and default route to Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "deema-public-rt-${var.env}"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# ✅ Security group for control plane
resource "aws_security_group" "control_plane_sg" {
  name        = "control-plane-sg-${var.env}"
  description = "Allow SSH, Kubernetes API, and internal VPC traffic"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API traffic"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow all traffic within the VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "deema-control-plane-sg-${var.env}"
  }
}

# ✅ Control plane EC2 instance
resource "aws_instance" "control_plane" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnets[0].id
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.control_plane_sg.id]

  user_data = file("${path.module}/user_data_control_plane.sh")
  iam_instance_profile = aws_iam_instance_profile.control_plane_profile.name

  tags = {
    Name = "deema-k8s-control-plane"
    Role = "control-plane"
  }
}

# ✅ Elastic IP for control plane
resource "aws_eip" "control_plane_eip" {
  instance = aws_instance.control_plane.id

  tags = {
    Name = "deema-control-plane-eip-${var.env}"
  }
}

# ✅ Security group for worker nodes
resource "aws_security_group" "worker_sg" {
  name        = "worker-sg-${var.env}"
  description = "Allow traffic for worker nodes"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow all traffic from within VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "deema-worker-sg-${var.env}"
  }
}

# ✅ Launch Template for worker EC2 instances
resource "aws_launch_template" "worker_lt" {
  name_prefix   = "k8s-worker-${var.env}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.worker_sg.id]
  }

  user_data = base64encode(file("${path.module}/user_data_worker.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "k8s-worker-${var.env}"
      Role = "worker"
    }
  }
}

# ✅ Auto Scaling Group for worker nodes
resource "aws_autoscaling_group" "worker_asg" {
  name                = "k8s-worker-asg-${var.env}"
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = aws_subnet.public_subnets[*].id
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.worker_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "k8s-worker-${var.env}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "worker"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
