output "vm_id" {
  description = "VM-ID der erstellten Instanz"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "ip_address" {
  description = "Konfigurierte IPv4-Adresse"
  value       = var.ip_address
}

output "node_name" {
  description = "Ziel-Proxmox-Node der Instanz"
  value       = var.node_name
}

output "memory_mb" {
  description = "Konfiguriertes RAM in MB"
  value       = var.memory_mb
}
