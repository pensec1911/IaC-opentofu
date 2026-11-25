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

output "bootstrap_has_secret" {
  description = "true = das Snippet enthaelt einen Private Key und liegt in salt_bootstrap_secret (ignore_changes)"
  value       = local.bootstrap_has_secret
}

output "bootstrap_rendered" {
  description = "Gerendertes cloud-init (fuer Tests)"
  value       = module.cloud_init.rendered
  sensitive   = true
}
