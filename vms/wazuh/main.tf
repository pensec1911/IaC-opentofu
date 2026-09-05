module "vm" {
  source = "../../modules/vm-instance"

  name        = "wazuh"
  node_name   = "pve01"
  template_id = var.template_id

  ip_address = "192.168.178.27/24"
  gateway    = "192.168.178.1"

  cpu_cores = 4
  memory_mb = 8192
  disk_size = 50

  ssh_public_key = var.ssh_public_key
}
