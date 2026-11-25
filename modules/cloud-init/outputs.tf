output "rendered" {
  description = "Gerendertes cloud-config. Immer sensitiv: wireguard_private_key ist eine sensitive Variable, und ihr Wert (auch null) markiert das ganze Template."
  value       = local.rendered
  sensitive   = true
}
