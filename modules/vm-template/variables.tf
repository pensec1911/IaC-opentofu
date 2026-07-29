variable "node_name" {
  description = "Proxmox-Node auf dem das Template erstellt wird"
  type        = string
}

variable "vm_id" {
  description = "Feste VM-ID für das Template (Konvention: 9000+)"
  type        = number

  validation {
    condition     = var.vm_id >= 9000
    error_message = "Template-VM-IDs sollen laut Konvention >= 9000 sein."
  }
}

variable "template_name" {
  description = "Name des Templates, z.B. debian13-template"
  type        = string
}

variable "image_url" {
  description = "URL des Cloud-Images (qcow2)"
  type        = string
}

variable "image_checksum" {
  description = "Checksum des Cloud-Images (optional, aber empfohlen)"
  type        = string
  default     = null
}

variable "image_checksum_algorithm" {
  description = "Algorithmus der Checksum, z.B. sha512"
  type        = string
  default     = "sha512"
}

variable "download_datastore_id" {
  description = "Datastore für den Cloud-Image-Download"
  type        = string
  default     = "local"
}

variable "disk_datastore_id" {
  description = "Datastore für die Template-Disk"
  type        = string
  default     = "local-lvm"
}

variable "disk_size" {
  description = "Disk-Größe in GB"
  type        = number
  default     = 20
}

variable "cpu_cores" {
  description = "CPU-Cores für das Template"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "RAM in MB für das Template"
  type        = number
  default     = 2048
}
