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

# WireGuard-Keys fuer gateway (README "OCI"). CI liest sie nicht
# (wireguard_from_vault = false) und rendert Platzhalter; das Snippet von
# gateway ignoriert Inhaltsaenderungen (modules/vm-instance, salt_bootstrap_secret).
data "vault_kv_secret_v2" "wg_gateway" {
  count = var.wireguard_from_vault ? 1 : 0
  mount = "homelab"
  name  = "wireguard/gateway"
}

data "vault_kv_secret_v2" "wg_cloud_edge" {
  count = var.wireguard_from_vault ? 1 : 0
  mount = "homelab"
  name  = "wireguard/cloud-edge"
}

locals {
  wg_gateway_private_key   = var.wireguard_from_vault ? data.vault_kv_secret_v2.wg_gateway[0].data["private_key"] : "ci-placeholder"
  wg_cloud_edge_public_key = var.wireguard_from_vault ? data.vault_kv_secret_v2.wg_cloud_edge[0].data["public_key"] : "ci-placeholder"
}
