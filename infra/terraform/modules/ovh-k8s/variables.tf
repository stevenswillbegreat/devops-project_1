variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "region" {
  description = "OVH Public Cloud region"
  type        = string
  default     = "GRA7"
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

variable "control_plane_flavor" {
  description = "Flavor for control plane nodes"
  type        = string
  default     = "s1-4"
}

variable "worker_flavor" {
  description = "Flavor for worker nodes"
  type        = string
  default     = "s1-8"
}

variable "node_image" {
  description = "OS image for nodes"
  type        = string
  default     = "Ubuntu 22.04"
}

variable "key_pair_name" {
  description = "Name of the key pair for SSH access"
  type        = string
}

variable "floating_ip_pool" {
  description = "Name of the floating IP pool"
  type        = string
  default     = "Ext-Net"
}