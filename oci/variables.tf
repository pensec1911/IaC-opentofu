variable "state_passphrase" {
  description = "Passphrase der State-Verschluesselung (OpenBao tofu-state/encryption) — dieselbe wie im Root-Modul"
  type        = string
  sensitive   = true
}

variable "vault_address" {
  description = "OpenBao-Endpoint"
  type        = string
  default     = "https://192.168.178.20:8200"
}

variable "vault_role_id" {
  description = "AppRole Role ID"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "AppRole Secret ID"
  type        = string
  sensitive   = true
}

variable "oci_vault_secret" {
  description = "KV-Pfad der OCI-API-Credentials (Keys tenancy_ocid, user_ocid, fingerprint, private_key, region, compartment_ocid). CI: oci/plan (nur lesend)."
  type        = string
  default     = "oci/api"
}

variable "wireguard_from_vault" {
  description = "WireGuard-Keys aus OpenBao lesen. CI setzt false: user_data wird nach dem ersten Boot ignoriert (lifecycle), Platzhalter erzeugen also keinen Diff, und die Plan-Jobs sehen nie einen privaten Key."
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "SSH-Public-Key fuer den Cloud-Init-User (nur ueber den Tunnel erreichbar, kein oeffentliches SSH)"
  type        = string
}

variable "salt_master_address" {
  description = "Salt-Master, erreichbar ueber den WireGuard-Tunnel und die FRITZ!Box-Route"
  type        = string
  default     = "192.168.178.28"
}

variable "use_platform_image" {
  description = "Fallback: Ubuntu 24.04 aarch64 von Oracle statt des importierten Debian-Images (README \"OCI\")"
  type        = bool
  default     = false
}

variable "availability_domain_index" {
  description = "Availability Domain (0-2). Bei \"Out of host capacity\" fuer A1 eine andere probieren."
  type        = number
  default     = 0
}
