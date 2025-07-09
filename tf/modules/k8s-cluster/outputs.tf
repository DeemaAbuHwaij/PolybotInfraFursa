output "control_plane_public_ip" {
  description = "Public IP address of the Kubernetes control plane EC2 instance"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_public_ip" {
  value = aws_instance.control_plane.public_ip
}
