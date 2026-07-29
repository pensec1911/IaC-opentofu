output "vm_id" {
  description = "VM-ID der erstellten Instanz"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "ip_address" {
  description = "Konfigurierte IPv4-Adresse"
  value       = var.ip_address
}
