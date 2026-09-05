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

  ip_address = "192.168.178.10/24"
  gateway    = "192.168.178.1"

  cpu_cores = 2
  memory_mb = 2048
  disk_size = 20

  ssh_public_key = var.ssh_public_key
}
module "jellyfin" {
  source = "./modules/vm-instance"

  name        = "jellyfin"
  node_name   = "pve01"
  template_id = module.debian13_template.vm_id

  ip_address = "192.168.178.12/24"
  gateway    = "192.168.178.1"

  cpu_cores = 4
  memory_mb = 4096
  disk_size = 32

  ssh_public_key = var.ssh_public_key
}

module "tailscale_router" {
  source = "./modules/vm-instance"

  name        = "tailscale-router"
  node_name   = "pve01"
  template_id = module.debian13_template.vm_id

  ip_address = "192.168.178.13/24"
  gateway    = "192.168.178.1"

  cpu_cores = 1
  memory_mb = 512
  disk_size = 8

  ssh_public_key = var.ssh_public_key
}

module "arrstack" {
  source = "./modules/vm-instance"

  name        = "arrstack"
  node_name   = "pve01"
  template_id = module.debian13_template.vm_id

  ip_address = "192.168.178.14/24"
  gateway    = "192.168.178.1"

  cpu_cores = 4
  memory_mb = 4096
  disk_size = 50

  ssh_public_key = var.ssh_public_key
}

module "wazuh" {
  source = "./modules/vm-instance"

  name        = "wazuh"
  node_name   = "pve01"
  template_id = module.debian13_template.vm_id

  ip_address = "192.168.178.15/24"
  gateway    = "192.168.178.1"

  cpu_cores = 4
  memory_mb = 8192
  disk_size = 50

  ssh_public_key = var.ssh_public_key
}

module "omada_controller" {
  source = "./modules/vm-instance"

  name        = "omada-controller"
  node_name   = "pve01"
  template_id = module.debian13_template.vm_id

  ip_address = "192.168.178.16/24"
  gateway    = "192.168.178.1"

  cpu_cores = 2
  memory_mb = 2048
  disk_size = 20

  ssh_public_key = var.ssh_public_key
}

#module "atlantis" {
#  source = "./modules/vm-instance"
#
#  name        = "atlantis"
#  node_name   = "pve01"
#  template_id = module.debian13_template.vm_id
#
#  ip_address = "192.168.178.11/24"
#  gateway    = "192.168.178.1"
#
#  cpu_cores = 2
#  memory_mb = 2048
#  disk_size = 20
#
#  ssh_public_key = var.ssh_public_key
#}
