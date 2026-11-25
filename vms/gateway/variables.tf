variable "template_ids" {
  description = "Template-VM-ID je Proxmox-Node. Die VM waehlt daraus das Template auf ihrem eigenen Node."
  type        = map(number)
}

variable "ssh_public_key" {
  description = "SSH-Public-Key für den Cloud-Init-User"
  type        = string
}

variable "wireguard_private_key" {
  description = "Privater WireGuard-Key von gateway (OpenBao wireguard/gateway)"
  type        = string
  sensitive   = true
}

variable "cloud_edge_public_key" {
  description = "WireGuard-Public-Key von cloud-edge (OpenBao wireguard/cloud-edge)"
  type        = string
}
