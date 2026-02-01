output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "control_plane_ips" {
  description = "Floating IP addresses of control plane nodes"
  value       = openstack_networking_floatingip_v2.control_plane_fip[*].address
}

output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = openstack_compute_instance_v2.workers[*].network.0.fixed_ip_v4
}

output "load_balancer_ip" {
  description = "Floating IP address of the load balancer"
  value       = openstack_networking_floatingip_v2.lb_fip.address
}

output "network_id" {
  description = "ID of the created network"
  value       = openstack_networking_network_v2.k8s_network.id
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "scp ubuntu@${openstack_networking_floatingip_v2.control_plane_fip[0].address}:/etc/kubernetes/admin.conf ~/.kube/config-ovh"
}