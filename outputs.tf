locals {
  # openbao, tailscale_router, omada_controller und wazuh sind in vms.tf aktuell auskommentiert.
  vm_inventory = {
    jellyfin = { ip = module.jellyfin.ip_address, node = module.jellyfin.node_name, memory_mb = module.jellyfin.memory_mb, cpu_cores = module.jellyfin.cpu_cores, disk_size = module.jellyfin.disk_size }
    arrstack = { ip = module.arrstack.ip_address, node = module.arrstack.node_name, memory_mb = module.arrstack.memory_mb, cpu_cores = module.arrstack.cpu_cores, disk_size = module.arrstack.disk_size }
    #wazuh       = { ip = module.wazuh.ip_address, node = module.wazuh.node_name, memory_mb = module.wazuh.memory_mb, cpu_cores = module.wazuh.cpu_cores, disk_size = module.wazuh.disk_size }
    monitoring  = { ip = module.monitoring.ip_address, node = module.monitoring.node_name, memory_mb = module.monitoring.memory_mb, cpu_cores = module.monitoring.cpu_cores, disk_size = module.monitoring.disk_size }
    homepage    = { ip = module.homepage.ip_address, node = module.homepage.node_name, memory_mb = module.homepage.memory_mb, cpu_cores = module.homepage.cpu_cores, disk_size = module.homepage.disk_size }
    forgejo     = { ip = module.forgejo.ip_address, node = module.forgejo.node_name, memory_mb = module.forgejo.memory_mb, cpu_cores = module.forgejo.cpu_cores, disk_size = module.forgejo.disk_size }
    salt_master = { ip = module.salt_master.ip_address, node = module.salt_master.node_name, memory_mb = module.salt_master.memory_mb, cpu_cores = module.salt_master.cpu_cores, disk_size = module.salt_master.disk_size }
  }

  memory_by_node_mb = {
    for node in distinct([for vm in local.vm_inventory : vm.node]) :
    node => sum([for vm in local.vm_inventory : vm.memory_mb if vm.node == node])
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
