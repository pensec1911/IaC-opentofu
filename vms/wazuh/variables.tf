variable "template_id" {
  description = "VM-ID des Templates, von dem geklont wird"
  type        = number
}

variable "ssh_public_key" {
  description = "SSH-Public-Key für den Cloud-Init-User"
  type        = string
}
