# PURPOSE: Complete Kubernetes Infrastructure
# This file defines VPC, networking, EC2 instances,
# IAM, Load Balancer, and access for S3/SQS/DynamoDB.

# ✅ VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "deema-k8s-vpc-${var.env}"
  }
}

# ✅ Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags = {
    Name = "deema-igw-${var.env}"
  }
}

# ✅ Public Subnets
resource "aws_subnet" "public_subnets" {
  count             = 2
  vpc_id            = aws_vpc.k8s_vpc.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone = var.azs[count.index]
  tags = {
    Name = "deema-public-subnet-${count.index}-${var.env}"
  }
}

# ✅ Route Table + Route
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

# ✅ IAM Role for EC2 - Control Plane
resource "aws_iam_role" "control_plane_role" {
  name = "deema-k8s-control-plane-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# ✅ IAM Role for EC2 - Worker
resource "aws_iam_role" "worker_role" {
  name = "deema-k8s-worker-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# ✅ Custom Policies
resource "aws_iam_policy" "s3_bot_policy" {
  name   = "deema-s3-bot-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:*"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "yolo_sqs_policy" {
  name   = "deema-sqs-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["sqs:*"],
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

resource "aws_iam_policy" "yolo_dynamodb_policy" {
  name   = "deema-ddb-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["dynamodb:*"],
        Resource = var.dynamodb_table_arn
      }
    ]
  })
}

# ✅ Attach IAM Policies
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = aws_iam_policy.s3_bot_policy.arn
}

resource "aws_iam_role_policy_attachment" "sqs_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.yolo_sqs_policy.arn
}

resource "aws_iam_role_policy_attachment" "ddb_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.yolo_dynamodb_policy.arn
}

# ✅ Instance Profiles
resource "aws_iam_instance_profile" "instance_profile" {
  name = "deema-k8s-control-plane-profile"
  role = aws_iam_role.control_plane_role.name
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "deema-k8s-worker-profile"
  role = aws_iam_role.worker_role.name
}

# ✅ EC2 Instance (Control Plane)
resource "aws_instance" "control_plane" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public_subnets[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.control_plane_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name

  tags = {
    Name = "deema-control-plane-${var.env}"
  }
}

# ✅ Security Groups
resource "aws_security_group" "control_plane_sg" {
  name   = "control-plane-sg"
  vpc_id = aws_vpc.k8s_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "worker_sg" {
  name   = "worker-sg"
  vpc_id = aws_vpc.k8s_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 31981
    to_port     = 31981
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb_sg" {
  name   = "lb-sg"
  vpc_id = aws_vpc.k8s_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

