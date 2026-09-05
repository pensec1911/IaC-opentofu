module "vm" {
  source = "../../modules/vm-instance"

  name        = "omada-controller"
  node_name   = "pve01"
  template_id = var.template_id

  ip_address = "192.168.178.16/24"
  gateway    = "192.168.178.1"

  cpu_cores = 2
  memory_mb = 2048
  disk_size = 20

  ssh_public_key = var.ssh_public_key
}
