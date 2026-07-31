data "vault_kv_secret_v2" "proxmox" {
  mount = "homelab"
  name  = "proxmox"
}
