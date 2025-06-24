resource "aws_security_group" "k8s_sg" {
  name   = "k8s-cluster-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
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

resource "aws_instance" "control_plane" {
  ami                         = "ami-014e30c8a36252ae5"
  instance_type               = "t3.medium"
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]
  user_data                   = file("${path.module}/user_data_control_plane.sh")
  user_data_replace_on_change = true
  iam_instance_profile        = local.control_plane_profile_name

  tags = {
    Name = "deema-task-k8s-control-plane"
  }
}

resource "aws_launch_template" "worker" {
  name_prefix   = "deema-k8s-worker-"
  image_id      = var.ami_id
  instance_type = var.worker_instance_type
  key_name      = var.key_name

  user_data = filebase64("${path.module}/user_data_worker.sh")
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "deema-k8s-worker"
    }
  }
}

resource "aws_autoscaling_group" "worker_asg" {
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  vpc_zone_identifier = var.worker_subnet_ids

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "deema-k8s-worker"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
