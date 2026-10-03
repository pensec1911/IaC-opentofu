variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, z.B. https://192.168.178.11:8006"
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
  default     = "http://192.168.178.20:8200"
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

variable "proxmox_ssh_private_key_path" {
  description = "Privater SSH-Key, mit dem sich der Provider als root auf die PVE-Nodes verbindet (fuer Snippet-Uploads). Muss in authorized_keys von root auf allen Nodes liegen."
  type        = string
  default     = "~/.ssh/homelab"
}
