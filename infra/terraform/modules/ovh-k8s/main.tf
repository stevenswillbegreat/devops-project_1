# OVH Public Cloud Kubernetes Cluster Module

# Network
resource "openstack_networking_network_v2" "k8s_network" {
  name           = "${var.cluster_name}-network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "k8s_subnet" {
  name       = "${var.cluster_name}-subnet"
  network_id = openstack_networking_network_v2.k8s_network.id
  cidr       = var.subnet_cidr
  ip_version = 4
}

resource "openstack_networking_router_v2" "k8s_router" {
  name                = "${var.cluster_name}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.ext_net.id
}

resource "openstack_networking_router_interface_v2" "k8s_router_interface" {
  router_id = openstack_networking_router_v2.k8s_router.id
  subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
}

# Security Group
resource "openstack_networking_secgroup_v2" "k8s_secgroup" {
  name        = "${var.cluster_name}-secgroup"
  description = "Security group for Kubernetes cluster"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroup.id
}

# Control Plane Nodes
resource "openstack_compute_instance_v2" "control_plane" {
  count           = var.control_plane_count
  name            = "${var.cluster_name}-control-${count.index + 1}"
  image_name      = var.node_image
  flavor_name     = var.control_plane_flavor
  key_pair        = var.key_pair_name
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]

  network {
    uuid = openstack_networking_network_v2.k8s_network.id
  }

  depends_on = [openstack_networking_router_interface_v2.k8s_router_interface]
}

# Worker Nodes
resource "openstack_compute_instance_v2" "workers" {
  count           = var.worker_count
  name            = "${var.cluster_name}-worker-${count.index + 1}"
  image_name      = var.node_image
  flavor_name     = var.worker_flavor
  key_pair        = var.key_pair_name
  security_groups = [openstack_networking_secgroup_v2.k8s_secgroup.name]

  network {
    uuid = openstack_networking_network_v2.k8s_network.id
  }

  depends_on = [openstack_compute_instance_v2.control_plane]
}

# Floating IPs for control plane
resource "openstack_networking_floatingip_v2" "control_plane_fip" {
  count = var.control_plane_count
  pool  = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "control_plane_fip_associate" {
  count       = var.control_plane_count
  floating_ip = openstack_networking_floatingip_v2.control_plane_fip[count.index].address
  instance_id = openstack_compute_instance_v2.control_plane[count.index].id
}

# Load Balancer
resource "openstack_lb_loadbalancer_v2" "k8s_lb" {
  name          = "${var.cluster_name}-lb"
  vip_subnet_id = openstack_networking_subnet_v2.k8s_subnet.id
}

resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool    = var.floating_ip_pool
  port_id = openstack_lb_loadbalancer_v2.k8s_lb.vip_port_id
}