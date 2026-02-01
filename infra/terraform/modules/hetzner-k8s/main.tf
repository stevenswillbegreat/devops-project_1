# Hetzner Cloud Kubernetes Cluster Module

# Network
resource "hcloud_network" "k8s_network" {
  name     = "${var.cluster_name}-network"
  ip_range = var.network_cidr
}

resource "hcloud_network_subnet" "k8s_subnet" {
  type         = "cloud"
  network_id   = hcloud_network.k8s_network.id
  network_zone = var.network_zone
  ip_range     = var.subnet_cidr
}

# Load Balancer
resource "hcloud_load_balancer" "k8s_lb" {
  name               = "${var.cluster_name}-lb"
  load_balancer_type = var.load_balancer_type
  location           = var.location
}

# Control Plane Nodes
resource "hcloud_server" "control_plane" {
  count       = var.control_plane_count
  name        = "${var.cluster_name}-control-${count.index + 1}"
  image       = var.node_image
  server_type = var.control_plane_type
  location    = var.location
  ssh_keys    = var.ssh_keys

  network {
    network_id = hcloud_network.k8s_network.id
  }

  depends_on = [hcloud_network_subnet.k8s_subnet]
}

# Worker Nodes
resource "hcloud_server" "workers" {
  count       = var.worker_count
  name        = "${var.cluster_name}-worker-${count.index + 1}"
  image       = var.node_image
  server_type = var.worker_type
  location    = var.location
  ssh_keys    = var.ssh_keys

  network {
    network_id = hcloud_network.k8s_network.id
  }

  depends_on = [hcloud_server.control_plane]
}

# Firewall
resource "hcloud_firewall" "k8s_firewall" {
  name = "${var.cluster_name}-firewall"

  rule {
    direction = "in"
    port      = "22"
    protocol  = "tcp"
    source_ips = var.allowed_ips
  }

  rule {
    direction = "in"
    port      = "6443"
    protocol  = "tcp"
    source_ips = var.allowed_ips
  }

  rule {
    direction = "in"
    port      = "80"
    protocol  = "tcp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    port      = "443"
    protocol  = "tcp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "k8s_firewall_attachment" {
  firewall_id = hcloud_firewall.k8s_firewall.id
  server_ids  = concat(hcloud_server.control_plane[*].id, hcloud_server.workers[*].id)
}