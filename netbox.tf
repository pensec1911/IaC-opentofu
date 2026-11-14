# NetBox als Inventar, OpenTofu ist die Quelle: jedes `tofu apply` schreibt
# Nodes, VMs und IPs nach NetBox (formulas/netbox in IaC-salt, auf forgejo).
# Nichts liest aus NetBox zurueck — weder Tofu noch Salt. Was hier verwaltet
# wird, nicht in der NetBox-UI aendern: der naechste Apply setzt es zurueck.
# Ports/Services stehen in IaC-salt (.claude/docs/inventory.md), nicht hier.
#
# NetBox down = `tofu plan/apply` schlaegt fehl (Refresh). Muss forgejo selbst
# neu gebaut werden: `tofu apply -target=module.forgejo` — dann wird der
# NetBox-Provider gar nicht erst konfiguriert. Danach ein normaler Apply.

locals {
  # Physische Geraete im LAN. Proxmox-Nodes kommen aus providers.tf.
  netbox_devices = merge(
    { for name, ip in local.pve_nodes : name => { ip = ip, role = "hypervisor" } },
    {
      truenas  = { ip = "192.168.178.10", role = "storage" }
      fritzbox = { ip = "192.168.178.1", role = "router" }
    },
  )

  netbox_device_roles = {
    hypervisor = { name = "Hypervisor", color = "2196f3" }
    storage    = { name = "Storage", color = "4caf50" }
    router     = { name = "Router", color = "ff9800" }
  }

  # VMs, die laufen, aber nicht (mehr) von Tofu verwaltet werden (vms.tf
  # auskommentiert, nicht im State). Nur Name/IP/Node — Groesse ist hier unbekannt.
  netbox_unmanaged_vms = {
    openbao            = { ip = "192.168.178.20/24", node = "pve03" }
    "tailscale-router" = { ip = "192.168.178.21/24", node = "pve01" }
  }

  # Minion-ID = VM-Name, also Bindestrich statt des Modul-Unterstrichs.
  netbox_vms = merge(
    {
      for key, vm in local.vm_inventory : replace(key, "_", "-") => {
        ip        = vm.ip
        node      = vm.node
        vcpus     = vm.cpu_cores
        memory_mb = vm.memory_mb
        disk_mb   = vm.disk_size == null ? null : vm.disk_size * 1024
        managed   = true
      }
    },
    {
      for name, vm in local.netbox_unmanaged_vms : name => {
        ip        = vm.ip
        node      = vm.node
        vcpus     = null
        memory_mb = null
        disk_mb   = null
        managed   = false
      }
    },
  )
}

resource "netbox_tag" "opentofu" {
  name        = "opentofu"
  color_hex   = "7b42bc"
  description = "Von IaC-opentofu verwaltet — Aenderungen in der UI werden beim naechsten Apply ueberschrieben"
}

resource "netbox_site" "home" {
  name     = "Home"
  slug     = "home"
  status   = "active"
  timezone = "Europe/Berlin"
}

resource "netbox_prefix" "lan" {
  prefix      = "192.168.178.0/24"
  status      = "active"
  site_id     = netbox_site.home.id
  description = "Flaches LAN (FRITZ!Box)"
  tags        = [netbox_tag.opentofu.name]
}

# --- physische Geraete ---------------------------------------------------------

resource "netbox_manufacturer" "generic" {
  name = "Generic"
}

resource "netbox_device_type" "generic" {
  manufacturer_id = netbox_manufacturer.generic.id
  model           = "Generic host"
}

resource "netbox_device_role" "this" {
  for_each = local.netbox_device_roles

  name      = each.value.name
  slug      = each.key
  color_hex = each.value.color
}

resource "netbox_cluster_type" "proxmox" {
  name = "Proxmox VE"
  slug = "proxmox-ve"
}

resource "netbox_cluster" "pve" {
  name            = "pve"
  cluster_type_id = netbox_cluster_type.proxmox.id
  site_id         = netbox_site.home.id
  tags            = [netbox_tag.opentofu.name]
}

resource "netbox_device" "this" {
  for_each = local.netbox_devices

  name           = each.key
  device_type_id = netbox_device_type.generic.id
  role_id        = netbox_device_role.this[each.value.role].id
  site_id        = netbox_site.home.id
  cluster_id     = each.value.role == "hypervisor" ? netbox_cluster.pve.id : null
  status         = "active"
  tags           = [netbox_tag.opentofu.name]
}

resource "netbox_device_interface" "this" {
  for_each = local.netbox_devices

  device_id = netbox_device.this[each.key].id
  name      = "lan"
  type      = "other"
}

resource "netbox_ip_address" "device" {
  for_each = local.netbox_devices

  ip_address          = "${each.value.ip}/24"
  status              = "active"
  device_interface_id = netbox_device_interface.this[each.key].id
  dns_name            = each.key
  tags                = [netbox_tag.opentofu.name]
}

resource "netbox_device_primary_ip" "this" {
  for_each = local.netbox_devices

  device_id     = netbox_device.this[each.key].id
  ip_address_id = netbox_ip_address.device[each.key].id
}

# --- VMs -------------------------------------------------------------------------

resource "netbox_virtual_machine" "this" {
  for_each = local.netbox_vms

  name         = each.key
  cluster_id   = netbox_cluster.pve.id
  device_id    = netbox_device.this[each.value.node].id
  vcpus        = each.value.vcpus
  memory_mb    = each.value.memory_mb
  disk_size_mb = each.value.disk_mb
  status       = "active"
  comments     = each.value.managed ? null : "Nicht von OpenTofu verwaltet (vms.tf auskommentiert) — nur Name, IP und Node sind gepflegt."
  tags         = [netbox_tag.opentofu.name]
}

resource "netbox_interface" "vm" {
  for_each = local.netbox_vms

  virtual_machine_id = netbox_virtual_machine.this[each.key].id
  name               = "net0"
}

resource "netbox_ip_address" "vm" {
  for_each = local.netbox_vms

  ip_address                   = each.value.ip
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.vm[each.key].id
  dns_name                     = each.key
  tags                         = [netbox_tag.opentofu.name]
}

resource "netbox_primary_ip" "vm" {
  for_each = local.netbox_vms

  virtual_machine_id = netbox_virtual_machine.this[each.key].id
  ip_address_id      = netbox_ip_address.vm[each.key].id
}
