variable "name" {
  description = "Hostname / VM-Name"
  type        = string
}

variable "node_name" {
  description = "Ziel-Proxmox-Node"
  type        = string
}

variable "template_id" {
  description = "VM-ID des Templates, von dem geklont wird"
  type        = number
}

variable "template_node_name" {
  description = "Node auf dem das Template liegt"
  type        = string
  default     = null
}

variable "vm_id" {
  description = "Optionale feste VM-ID, sonst Proxmox Auto-Assign"
  type        = number
  default     = null
}

variable "vlan_id" {
  description = "VLAN-Tag für das Netzwerk-Interface (null = untagged, flaches Netz)"
  type        = number
  default     = null
}

variable "bridge" {
  description = "Ziel-Bridge"
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  description = "Statische IPv4-Adresse inkl. CIDR, z.B. 192.168.40.10/24"
  type        = string
}

variable "gateway" {
  description = "IPv4-Gateway"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH-Public-Key für den Cloud-Init-User"
  type        = string
}

variable "ci_username" {
  description = "Cloud-Init-Username"
  type        = string
  default     = "debian"
}

variable "cpu_cores" {
  description = "CPU-Cores für die VM"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "RAM in MB für die VM"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Disk-Größe in GB (nur relevant falls größer als Template-Disk)"
  type        = number
  default     = null
}

variable "full_clone" {
  description = "Full Clone statt Linked Clone"
  type        = bool
  default     = true
}
