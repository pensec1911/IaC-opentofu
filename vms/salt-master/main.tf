locals {
  node = "pve02"
}

module "vm" {
  source = "../../modules/vm-instance"

  name        = "salt-master"
  node_name   = local.node
  template_id = var.template_ids[local.node]

  ip_address = "192.168.178.28/24"
  gateway    = "192.168.178.1"

  cpu_cores = 2
  memory_mb = 4096
  disk_size = 20

  ssh_public_key      = var.ssh_public_key
  install_salt_master = true
  salt_master_address = "192.168.178.28"
}
