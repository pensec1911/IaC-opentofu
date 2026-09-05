module "vm" {
  source = "../../modules/vm-instance"

  name        = "jellyfin"
  node_name   = "pve02"
  template_id = var.template_id

  ip_address = "192.168.178.24/24"
  gateway    = "192.168.178.1"

  cpu_cores = 4
  memory_mb = 4096
  disk_size = 32

  ssh_public_key = var.ssh_public_key
}
