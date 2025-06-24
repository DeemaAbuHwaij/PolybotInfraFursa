resource "aws_instance" "control_plane" {
  ami           = "ami-014e30c8a36252ae5"   #✅ Ubuntu 22.04 in us-west-1
  instance_type = "t3.medium"
  key_name      = var.key_name

  user_data = file("${path.module}/user_data_control_plane.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "deema-task-k8s-control-plane"
  }

  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  subnet_id = var.subnet_id  # 👈 Must be passed from root (see note below)
}

resource "aws_security_group" "k8s_sg" {
  name   = "k8s-cluster-sg"
  vpc_id = var.vpc_id

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
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
