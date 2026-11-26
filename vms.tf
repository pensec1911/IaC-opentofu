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

module "arrstack" {
  source = "./vms/arrstack"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

# wazuh: 2026-11-11 abgeschaltet (8 GB auf pve01), 2026-11-26 wieder an — pve01
# hat jetzt 32 GB. Agents schaltet IaC-salt pillar/features.jinja `wazuh` frei.
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

module "forgejo" {
  source = "./vms/forgejo"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

module "salt_master" {
  source = "./vms/salt-master"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

# Verwaltungstunnel zu cloud-edge (oci/) + spaeter Tailscale-Subnet-Router.
module "gateway" {
  source = "./vms/gateway"

  template_ids          = local.template_ids
  ssh_public_key        = var.ssh_public_key
  wireguard_private_key = local.wg_gateway_private_key
  cloud_edge_public_key = local.wg_cloud_edge_public_key
}

# Caddy + Authentik (IaC-salt).
module "edge" {
  source = "./vms/edge"

  template_ids   = local.template_ids
  ssh_public_key = var.ssh_public_key
}

locals {
  template_ids = { for node, tpl in module.debian13_template : node => tpl.vm_id }
}
