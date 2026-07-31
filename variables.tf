variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, z.B. https://pve01.ilpaa.xyz:8006"
  type        = string
}

#variable "proxmox_api_token" {
#  description = "API Token im Format terraform@pve!tofu-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#  type        = string
#  sensitive   = true
#}

variable "proxmox_insecure" {
  description = "TLS-Zertifikatsprüfung überspringen (nur für selbstsigniertes PVE-Zertifikat)"
  type        = bool
  default     = true
}

variable "target_node" {
  description = "Name des Proxmox-Nodes, auf dem die VM erstellt wird (z.B. pve01)"
  type        = string
}

variable "vm_ssh_public_key" {
  description = "Öffentlicher SSH-Key, der per cloud-init in die VM injiziert wird"
  type        = string
}
variable "ssh_public_key" {
  description = "SSH-Public-Key für Cloud-Init-User"
  type        = string
}
variable "vault_address" {
  description = "OpenBao-Endpoint"
  type        = string
  default     = "http://192.168.40.10:8200"
}

variable "vault_role_id" {
  description = "AppRole Role ID fuer OpenTofu"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "AppRole Secret ID fuer OpenTofu"
  type        = string
  sensitive   = true
}
