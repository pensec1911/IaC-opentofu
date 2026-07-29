module "debian13_template" {
  source = "./modules/vm-template"

  node_name     = "pve01"
  vm_id         = 9000
  template_name = "debian13-template"

  image_url = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  # image_checksum = "..." # optional: SHA512-Checksum eintragen für Reproduzierbarkeit
}
module "openbao" {
  source = "./modules/vm-instance"

  name        = "openbao"
  node_name   = "pve01"
  template_id = module.debian13_template.vm_id

  vlan_id    = 40
  ip_address = "192.168.40.10/24"
  gateway    = "192.168.40.1"

  cpu_cores = 2
  memory_mb = 2048
  disk_size = 20

  ssh_public_key = var.ssh_public_key
}
