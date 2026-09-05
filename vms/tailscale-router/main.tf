module "vm" {
  source = "../../modules/vm-instance"

  name        = "tailscale-router"
  node_name   = "pve01"
  template_id = var.template_id

  ip_address = "192.168.178.21/24"
  gateway    = "192.168.178.1"

  cpu_cores = 1
  memory_mb = 512
  disk_size = 8

  ssh_public_key = var.ssh_public_key
}
