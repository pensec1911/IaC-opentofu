# Debian 13 genericcloud arm64 als Custom Image: Import als QCOW2 aus dem
# Bucket, dann UEFI-Firmware und die A1-Shape freischalten (importierte
# Images kennen von sich aus nur x86-Shapes).
# Das Objekt selbst laedt nicht Tofu hoch: der Provider prueft die lokale
# Datei bei jedem Plan, CI haette sie nie. `make oci-image` laedt und prueft
# das qcow2 (SHA512SUMS), hochgeladen wird es einmalig in der Konsole oder
# per OCI-CLI (README "OCI", zweistufiger erster Apply).
# Fallback (use_platform_image): Oracles Ubuntu 24.04 aarch64, README "OCI".
locals {
  image_object = "debian-13-genericcloud-arm64.qcow2"
  import_image = !var.use_platform_image
  image_id     = local.import_image ? oci_core_image.debian[0].id : data.oci_core_images.ubuntu[0].images[0].id
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = local.oci.tenancy_ocid
}

resource "oci_objectstorage_bucket" "images" {
  count          = local.import_image ? 1 : 0
  compartment_id = local.compartment_id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "homelab-images"
  access_type    = "NoPublicAccess"
}

resource "oci_core_image" "debian" {
  count          = local.import_image ? 1 : 0
  compartment_id = local.compartment_id
  display_name   = "debian-13-genericcloud-arm64"
  launch_mode    = "PARAVIRTUALIZED"

  image_source_details {
    source_type              = "objectStorageTuple"
    namespace_name           = data.oci_objectstorage_namespace.this.namespace
    bucket_name              = oci_objectstorage_bucket.images[0].name
    object_name              = local.image_object
    source_image_type        = "QCOW2"
    operating_system         = "Debian"
    operating_system_version = "13"
  }

  timeouts {
    create = "60m"
  }

  # Das Objekt darf nach dem Import aus dem Bucket geloescht werden.
  lifecycle {
    ignore_changes = [image_source_details]
  }
}

data "oci_core_compute_global_image_capability_schemas" "this" {}

resource "oci_core_compute_image_capability_schema" "debian" {
  count                                               = local.import_image ? 1 : 0
  compartment_id                                      = local.compartment_id
  image_id                                            = oci_core_image.debian[0].id
  compute_global_image_capability_schema_version_name = data.oci_core_compute_global_image_capability_schemas.this.compute_global_image_capability_schemas[0].current_version_name

  schema_data = {
    "Compute.Firmware" = jsonencode({
      descriptorType = "enumstring"
      source         = "IMAGE"
      defaultValue   = "UEFI_64"
      values         = ["UEFI_64"]
    })
  }
}

resource "oci_core_shape_management" "debian_a1" {
  count          = local.import_image ? 1 : 0
  compartment_id = local.compartment_id
  image_id       = oci_core_image.debian[0].id
  shape_name     = local.shape
}

data "oci_core_images" "ubuntu" {
  count                    = var.use_platform_image ? 1 : 0
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = local.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
