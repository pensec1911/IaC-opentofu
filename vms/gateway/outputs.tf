output "vm_id" {
  value = module.vm.vm_id
}

output "ip_address" {
  value = module.vm.ip_address
}

output "node_name" {
  value = module.vm.node_name
}

output "memory_mb" {
  value = module.vm.memory_mb
}

output "cpu_cores" {
  value = module.vm.cpu_cores
}

output "disk_size" {
  value = module.vm.disk_size
}

output "bootstrap_has_secret" {
  value = module.vm.bootstrap_has_secret
}

output "bootstrap_rendered" {
  value     = module.vm.bootstrap_rendered
  sensitive = true
}
