variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location"
  type        = string
  default     = "nbg1"
}

variable "network_zone" {
  description = "Network zone for the subnet"
  type        = string
  default     = "eu-central"
}

variable "network_cidr" {
  description = "CIDR block for the network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "control_plane_type" {
  description = "Server type for control plane nodes"
  type        = string
  default     = "cx21"
}

variable "worker_type" {
  description = "Server type for worker nodes"
  type        = string
  default     = "cx31"
}

variable "node_image" {
  description = "OS image for nodes"
  type        = string
  default     = "ubuntu-22.04"
}

variable "load_balancer_type" {
  description = "Load balancer type"
  type        = string
  default     = "lb11"
}

variable "ssh_keys" {
  description = "List of SSH key names"
  type        = list(string)
}

variable "allowed_ips" {
  description = "List of allowed IP addresses for SSH and API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}