# Offsite-Kopie der restic-Repos (IaC-salt formulas/backup-offsite): ein
# privater Bucket, in den der salt-master per S3-kompatibler API nachts
# `restic copy` schreibt. Always Free deckt 20 GB Object Storage ab, die
# Repos sind zusammen < 1 GB.
#
# IAM (User/Gruppe/Policy) und den Customer Secret Key legt NICHT Tofu an:
# tofu-admins darf nur im Compartment homelab verwalten (User und Gruppen
# sind Tenancy-weit), und der Secret Key laege sonst im State. Manuelle
# Schritte: README "OCI" → "Offsite-Bucket".
resource "oci_objectstorage_bucket" "restic" {
  compartment_id = local.compartment_id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "homelab-restic"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Disabled"

  # Haelt die einzige Kopie ausser Haus — nie per Plan wegraeumen.
  lifecycle {
    prevent_destroy = true
  }
}
