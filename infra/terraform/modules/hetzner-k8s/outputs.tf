output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "control_plane_ips" {
  description = "Public IP addresses of control plane nodes"
  value       = hcloud_server.control_plane[*].ipv4_address
}

output "worker_ips" {
  description = "Public IP addresses of worker nodes"
  value       = hcloud_server.workers[*].ipv4_address
}

output "load_balancer_ip" {
  description = "Public IP address of the load balancer"
  value       = hcloud_load_balancer.k8s_lb.ipv4
}

output "network_id" {
  description = "ID of the created network"
  value       = hcloud_network.k8s_network.id
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "scp root@${hcloud_server.control_plane[0].ipv4_address}:/etc/kubernetes/admin.conf ~/.kube/config-hetzner"
}