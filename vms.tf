# openbao wird nie mit OpenTofu erstellt/verwaltet — einmalig manuell für Secrets angelegt.
#module "openbao" {
#  source = "./vms/openbao"
#
#  template_ids   = local.template_ids
#  ssh_public_key = var.ssh_public_key
#}

module "jellyfin" {
  source = "./vms/jellyfin"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

#module "tailscale_router" {
#  source = "./vms/tailscale-router"
#
#  template_ids   = local.template_ids
#  ssh_public_key = var.ssh_public_key
#}

module "arrstack" {
  source = "./vms/arrstack"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

module "wazuh" {
  source = "./vms/wazuh"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

#module "omada_controller" {
#  source = "./vms/omada-controller"
#
#  template_ids   = local.template_ids
#  ssh_public_key = var.ssh_public_key
#}

module "monitoring" {
  source = "./vms/monitoring"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

module "homepage" {
  source = "./vms/homepage"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

module "salt_master" {
  source = "./vms/salt-master"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

locals {
  template_ids = { for node, tpl in module.debian13_template : node => tpl.vm_id }
}
