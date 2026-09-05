module "vm" {
  source = "../../modules/vm-instance"

  name        = "monitoring"
  node_name   = "pve01"
  template_id = var.template_id

  ip_address = "192.168.178.17/24"
  gateway    = "192.168.178.1"

  cpu_cores = 2
  memory_mb = 4096
  disk_size = 40

  ssh_public_key = var.ssh_public_key
}
