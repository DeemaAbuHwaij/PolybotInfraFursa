############################################
# PURPOSE: Complete Kubernetes Infrastructure
# This file defines VPC, networking, EC2 instances,
# IAM, Load Balancer, and access for S3/SQS/DynamoDB.
############################################

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

# ✅ IAM Role for EC2
resource "aws_iam_role" "control_plane_role" {
  name = "deema-k8s-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
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
  role       = aws_iam_role.control_plane_role.name
  policy_arn = aws_iam_policy.yolo_sqs_policy.arn
}

resource "aws_iam_role_policy_attachment" "ddb_attach" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = aws_iam_policy.yolo_dynamodb_policy.arn
}

# ✅ Instance Profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "deema-k8s-profile"
  role = aws_iam_role.control_plane_role.name
}

# ✅ Security Groups
resource "aws_security_group" "control_plane_sg" {
  name   = "control-plane-sg"
  vpc_id = aws_vpc.k8s_vpc.id

  ingress { from_port = 22 to_port = 22 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 6443 to_port = 6443 protocol = "tcp" cidr_blocks = [var.vpc_cidr] }
  ingress { from_port = 10250 to_port = 10250 protocol = "tcp" cidr_blocks = [var.vpc_cidr] }
  ingress { from_port = 179 to_port = 179 protocol = "tcp" cidr_blocks = [var.vpc_cidr] }
  ingress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = [var.vpc_cidr] }

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "worker_sg" {
  name   = "worker-sg"
  vpc_id = aws_vpc.k8s_vpc.id

  ingress { from_port = 22 to_port = 22 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 31981 to_port = 31981 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = [var.vpc_cidr] }

  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_security_group" "lb_sg" {
  name   = "lb-sg"
  vpc_id = aws_vpc.k8s_vpc.id
  ingress { from_port = 443 to_port = 443 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
}

# ✅ EC2 Control Plane
resource "aws_instance" "control_plane" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.control_plane_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  user_data                   = file("${path.module}/user_data_control_plane.sh")
  tags = { Name = "control-plane" }
}

# ✅ Worker Launch Template
resource "aws_launch_template" "worker" {
  name_prefix   = "worker-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile { name = aws_iam_instance_profile.instance_profile.name }
  user_data = base64encode(file("${path.module}/user_data_worker.sh"))

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.worker_sg.id, aws_security_group.control_plane_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "worker" }
  }
}

# ✅ Worker ASG
resource "aws_autoscaling_group" "worker_asg" {
  name                = "worker-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = aws_subnet.public_subnets[*].id
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "worker"
    propagate_at_launch = true
  }
}

# ✅ Load Balancer + Target Group
resource "aws_lb" "k8s_lb" {
  name               = "k8s-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnets[*].id
  security_groups    = [aws_security_group.lb_sg.id]
}

resource "aws_lb_target_group" "nginx_nodeport_tg" {
  name     = "nginx-tg"
  port     = 31981
  protocol = "HTTP"
  vpc_id   = aws_vpc.k8s_vpc.id

  health_check {
    path                = "/healthz"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.k8s_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_nodeport_tg.arn
  }
}

resource "aws_autoscaling_attachment" "asg_lb_attach" {
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
  lb_target_group_arn    = aws_lb_target_group.nginx_nodeport_tg.arn
}

# ✅ S3, SQS, DynamoDB Policies
resource "aws_iam_policy" "s3_bot_policy" {
  name   = "ImageBotS3Access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["s3:PutObject", "s3:GetObject"],
      Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
    }]
  })
}

resource "aws_iam_policy" "yolo_sqs_policy" {
  name   = "YoloSQSAccess"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
      Resource = var.sqs_queue_arn
    }]
  })
}

resource "aws_iam_policy" "yolo_dynamodb_policy" {
  name   = "YoloDynamoDBAccess"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"],
      Resource = var.dynamodb_table_arn
    }]
  })
}
