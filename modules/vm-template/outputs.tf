output "vm_id" {
  description = "VM-ID des erstellten Templates"
  value       = proxmox_virtual_environment_vm.template.vm_id
}

output "node_name" {
  description = "Node, auf dem das Template liegt"
  value       = proxmox_virtual_environment_vm.template.node_name
}
