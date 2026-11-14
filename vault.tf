data "vault_kv_secret_v2" "proxmox" {
  mount = "homelab"
  name  = "proxmox"
}

# API-Token (v2, nbt_…) des NetBox-Users `opentofu`, manuell angelegt — siehe
# README "NetBox".
data "vault_kv_secret_v2" "netbox" {
  mount = "homelab"
  name  = "netbox/tofu"
}
