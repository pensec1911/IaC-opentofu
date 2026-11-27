output "public_ip" {
  description = "Reservierte oeffentliche IP von cloud-edge — A-Record hs.<domain> (manuell, README \"OCI\") und WireGuard-Endpoint von gateway"
  value       = oci_core_public_ip.cloud_edge.ip_address
}

output "wireguard_endpoint" {
  description = "Endpoint fuer den gateway-Peer"
  value       = "${oci_core_public_ip.cloud_edge.ip_address}:${local.wg_port}"
}

output "instance_id" {
  description = "OCID der Instanz (Serial Console, Konsole)"
  value       = oci_core_instance.cloud_edge.id
}

output "shape" {
  description = "Shape und Groesse (fuer Tests/Uebersicht)"
  value       = { shape = local.shape, ocpus = local.ocpus, memory_gb = local.memory_gb, boot_volume_gb = local.boot_volume_gb }
}

output "restic_offsite_repository" {
  description = "restic-Repo-Basis der Offsite-Kopie (IaC-salt pillar/backup-offsite.sls, je Minion /<minion> dahinter)"
  value       = "s3:https://${data.oci_objectstorage_namespace.this.namespace}.compat.objectstorage.${nonsensitive(local.oci.region)}.oraclecloud.com/${oci_objectstorage_bucket.restic.name}"
}
