# PURPOSE: Complete Kubernetes Infrastructure
# This file defines VPC, networking, EC2 instances,
# IAM, Load Balancer, and access for S3/SQS/DynamoDB.

# ✅ VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "k8s-deema-vpc-${var.env}"
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
    Name = "k8s-deema-public-subnet-${count.index}-${var.env}"
  }
}

# ✅ Route Table + Route
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags = {
    Name = "k8s-deema-public-rt-${var.env}"
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
  name = "k8s-deema-control-plane-role"
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
  name = "k8s-deema-worker-role"
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
  name   = "k8s-deema-s3-bot-policy-${var.env}"
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
  name   = "k8s-deema-sqs-policy-${var.env}"
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
  name   = "k8s-deema-ddb-policy-${var.env}"
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
  name = "k8s--deema-control-plane-profile"
  role = aws_iam_role.control_plane_role.name
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "k8s--deema-worker-profile"
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
    Name = "k8s-deema-control-plane-${var.env}"
  }
}



# ✅ Elastic IP
resource "aws_eip" "control_plane_eip" {
  instance = aws_instance.control_plane.id
  vpc      = true

  tags = {
    Name = "k8s-deema-control-plane-eip-${var.env}"
  }
}


# ✅ Security Groups
resource "aws_security_group" "control_plane_sg" {
  name   = "k8s-deema-control-plane-sg"
  vpc_id = aws_vpc.k8s_vpc.id

  lifecycle {
  create_before_destroy = true
  }


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
  name   = "k8s-deema-worker-sg"
  vpc_id = aws_vpc.k8s_vpc.id

  lifecycle {
  create_before_destroy = true
  }


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
  name   = "k8s-deema-lb-sg"
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

# ✅ Launch Template for Worker Nodes
resource "aws_launch_template" "worker" {
  name_prefix   = "k8s-worker"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_profile.name
  }

  user_data = base64encode(file("${path.module}/user_data_worker.sh"))

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [
      aws_security_group.control_plane_sg.id,
      aws_security_group.worker_sg.id
    ]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "k8s-worker"
    }
  }
}

# ✅ Auto Scaling Group for Worker Nodes
resource "aws_autoscaling_group" "worker_asg" {
  name                      = "k8s-deema-worker-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  health_check_type         = "EC2"
  force_delete              = true
  vpc_zone_identifier       = [for subnet in aws_subnet.public_subnets : subnet.id]

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "k8s-worker"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ✅ Load Balancer
resource "aws_lb" "k8s_lb" {
  name               = "k8s-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  tags = {
    Name = "k8s-lb"
  }
}

# ✅ Target Group
resource "aws_lb_target_group" "nginx_nodeport_tg" {
  name        = "nginx-nodeport-tg"
  port        = 31981
  protocol    = "HTTP"
  vpc_id      = aws_vpc.k8s_vpc.id
  target_type = "instance"

  health_check {
    path                = "/healthz"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ✅ HTTPS Listener
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

# ✅ Attach Worker ASG to LB Target Group
resource "aws_autoscaling_attachment" "nginx_asg_lb_attachment" {
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
  lb_target_group_arn    = aws_lb_target_group.nginx_nodeport_tg.arn
}

# ✅ Allow Worker-to-Worker Communication
resource "aws_security_group_rule" "allow_worker_to_worker_all" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.worker_sg.id
  source_security_group_id = aws_security_group.worker_sg.id
  description              = "Allow all traffic between worker nodes"
}