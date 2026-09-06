module "openbao" {
  source = "./vms/openbao"

  template_id    = module.debian13_template.vm_id
  ssh_public_key = var.ssh_public_key
}

module "jellyfin" {
  source = "./vms/jellyfin"

  template_id    = module.debian13_template.vm_id
  ssh_public_key = var.ssh_public_key
}

module "tailscale_router" {
  source = "./vms/tailscale-router"

  template_id    = module.debian13_template.vm_id
  ssh_public_key = var.ssh_public_key
}

module "arrstack" {
  source = "./vms/arrstack"

  template_id    = module.debian13_template.vm_id
  ssh_public_key = var.ssh_public_key
}

module "wazuh" {
  source = "./vms/wazuh"

  template_id    = module.debian13_template.vm_id
  ssh_public_key = var.ssh_public_key
}

module "omada_controller" {
  source = "./vms/omada-controller"

  template_id    = module.debian13_template.vm_id
  ssh_public_key = var.ssh_public_key
}

module "monitoring" {
  source = "./vms/monitoring"

  template_id    = module.debian13_template.vm_id
  ssh_public_key = var.ssh_public_key
}

module "homepage" {
  source = "./vms/homepage"

  template_id    = module.debian13_template.vm_id
  ssh_public_key = var.ssh_public_key
}

module "salt_master" {
  source = "./vms/salt-master"

  template_id    = module.debian13_template.vm_id
  ssh_public_key = var.ssh_public_key
}