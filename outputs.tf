locals {
  # openbao und omada_controller sind in vms.tf aktuell auskommentiert.
  vm_inventory = {
    jellyfin    = { ip = module.jellyfin.ip_address, node = module.jellyfin.node_name, memory_mb = module.jellyfin.memory_mb, cpu_cores = module.jellyfin.cpu_cores, disk_size = module.jellyfin.disk_size }
    arrstack    = { ip = module.arrstack.ip_address, node = module.arrstack.node_name, memory_mb = module.arrstack.memory_mb, cpu_cores = module.arrstack.cpu_cores, disk_size = module.arrstack.disk_size }
    wazuh       = { ip = module.wazuh.ip_address, node = module.wazuh.node_name, memory_mb = module.wazuh.memory_mb, cpu_cores = module.wazuh.cpu_cores, disk_size = module.wazuh.disk_size }
    monitoring  = { ip = module.monitoring.ip_address, node = module.monitoring.node_name, memory_mb = module.monitoring.memory_mb, cpu_cores = module.monitoring.cpu_cores, disk_size = module.monitoring.disk_size }
    homepage    = { ip = module.homepage.ip_address, node = module.homepage.node_name, memory_mb = module.homepage.memory_mb, cpu_cores = module.homepage.cpu_cores, disk_size = module.homepage.disk_size }
    forgejo     = { ip = module.forgejo.ip_address, node = module.forgejo.node_name, memory_mb = module.forgejo.memory_mb, cpu_cores = module.forgejo.cpu_cores, disk_size = module.forgejo.disk_size }
    gateway     = { ip = module.gateway.ip_address, node = module.gateway.node_name, memory_mb = module.gateway.memory_mb, cpu_cores = module.gateway.cpu_cores, disk_size = module.gateway.disk_size }
    edge        = { ip = module.edge.ip_address, node = module.edge.node_name, memory_mb = module.edge.memory_mb, cpu_cores = module.edge.cpu_cores, disk_size = module.edge.disk_size }
    docs        = { ip = module.docs.ip_address, node = module.docs.node_name, memory_mb = module.docs.memory_mb, cpu_cores = module.docs.cpu_cores, disk_size = module.docs.disk_size }
    salt_master = { ip = module.salt_master.ip_address, node = module.salt_master.node_name, memory_mb = module.salt_master.memory_mb, cpu_cores = module.salt_master.cpu_cores, disk_size = module.salt_master.disk_size }
  }

  # Physischer RAM je Proxmox-Node, Grenze fuer tests/fleet.tftest.hcl.
  # pve01 seit 2026-11-26 auf 32 GB aufgeruestet.
  node_memory_mb = {
    pve01 = 32768
    pve02 = 16384
    pve03 = 16384
  }

  # Inkl. der nicht von Tofu verwalteten VMs (netbox.tf), die laufen ja trotzdem.
  memory_by_node_mb = {
    for node in distinct(concat([for vm in local.vm_inventory : vm.node], [for vm in local.netbox_unmanaged_vms : vm.node])) :
    node => sum(concat(
      [for vm in local.vm_inventory : vm.memory_mb if vm.node == node],
      [for vm in local.netbox_unmanaged_vms : vm.memory_mb if vm.node == node],
    ))
  }
}

output "vm_inventory" {
  description = "IP, Node, RAM, CPU und Disk je VM (für Tests, Übersicht und NetBox)"
  value       = local.vm_inventory
}

output "memory_by_node_mb" {
  description = "Summierter RAM-Verbrauch je Proxmox-Node"
  value       = local.memory_by_node_mb
}

output "node_memory_mb" {
  description = "Physischer RAM je Proxmox-Node (Grenze fuer memory_by_node_mb)"
  value       = local.node_memory_mb
}
