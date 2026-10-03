locals {
  node = "pve03"
}

module "vm" {
  source = "../../modules/vm-instance"

  name        = "arrstack"
  node_name   = local.node
  template_id = var.template_ids[local.node]

  ip_address = "192.168.178.22/24"
  gateway    = "192.168.178.1"

  cpu_cores = 4
  memory_mb = 4096
  disk_size = 100

  ssh_public_key      = var.ssh_public_key
  salt_master_address = "192.168.178.28"
}
