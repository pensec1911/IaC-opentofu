locals {
  # openbao, tailscale_router und omada_controller sind in vms.tf aktuell auskommentiert.
  vm_inventory = {
    jellyfin    = { ip = module.jellyfin.ip_address, node = module.jellyfin.node_name, memory_mb = module.jellyfin.memory_mb }
    arrstack    = { ip = module.arrstack.ip_address, node = module.arrstack.node_name, memory_mb = module.arrstack.memory_mb }
    wazuh       = { ip = module.wazuh.ip_address, node = module.wazuh.node_name, memory_mb = module.wazuh.memory_mb }
    monitoring  = { ip = module.monitoring.ip_address, node = module.monitoring.node_name, memory_mb = module.monitoring.memory_mb }
    homepage    = { ip = module.homepage.ip_address, node = module.homepage.node_name, memory_mb = module.homepage.memory_mb }
    salt_master = { ip = module.salt_master.ip_address, node = module.salt_master.node_name, memory_mb = module.salt_master.memory_mb }
  }

  memory_by_node_mb = {
    for node in distinct([for vm in local.vm_inventory : vm.node]) :
    node => sum([for vm in local.vm_inventory : vm.memory_mb if vm.node == node])
  }
}

output "vm_inventory" {
  description = "IP, Node und RAM je VM (für Tests und Übersicht)"
  value       = local.vm_inventory
}

output "memory_by_node_mb" {
  description = "Summierter RAM-Verbrauch je Proxmox-Node"
  value       = local.memory_by_node_mb
}
