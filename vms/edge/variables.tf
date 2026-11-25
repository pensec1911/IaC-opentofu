variable "template_ids" {
  description = "Template-VM-ID je Proxmox-Node. Die VM waehlt daraus das Template auf ihrem eigenen Node."
  type        = map(number)
}

variable "ssh_public_key" {
  description = "SSH-Public-Key für den Cloud-Init-User"
  type        = string
}
