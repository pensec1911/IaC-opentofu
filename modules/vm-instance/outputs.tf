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

output "cpu_cores" {
  description = "Konfigurierte CPU-Cores"
  value       = var.cpu_cores
}

output "disk_size" {
  description = "Konfigurierte Disk-Groesse in GB (null = Template-Groesse)"
  value       = var.disk_size
}
