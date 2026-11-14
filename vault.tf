data "vault_kv_secret_v2" "proxmox" {
  mount = "homelab"
  name  = var.proxmox_vault_secret
}

# API-Token (v2, nbt_…) des NetBox-Users `opentofu`, manuell angelegt — siehe
# README "NetBox".
data "vault_kv_secret_v2" "netbox" {
  mount = "homelab"
  name  = var.netbox_vault_secret
}
