locals {
  node = "pve02"
}

module "vm" {
  source = "../../modules/vm-instance"

  name      = "monitoring"
  node_name = local.node
  # Feste ID: die Firewall-Regeln (firewall.tf) haengen an ihr.
  vm_id       = 101
  template_id = var.template_ids[local.node]

  ip_address = "192.168.178.25/24"
  gateway    = "192.168.178.1"

  cpu_cores = 2
  memory_mb = 4096
  disk_size = 40

  ssh_public_key      = var.ssh_public_key
  salt_master_address = "192.168.178.28"
}
