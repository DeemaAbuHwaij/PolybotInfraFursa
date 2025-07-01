output "control_plane_ip" {
  description = "Kubernetes control plane public IP"
  value       = module.k8s_cluster.control_plane_public_ip
}

