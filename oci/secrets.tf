data "vault_kv_secret_v2" "oci" {
  mount = "homelab"
  name  = var.oci_vault_secret
}

# README "OCI" / IaC-salt Schritt 0: je Endpunkt private_key + public_key.
data "vault_kv_secret_v2" "wg_cloud_edge" {
  count = var.wireguard_from_vault ? 1 : 0
  mount = "homelab"
  name  = "wireguard/cloud-edge"
}

data "vault_kv_secret_v2" "wg_gateway" {
  count = var.wireguard_from_vault ? 1 : 0
  mount = "homelab"
  name  = "wireguard/gateway"
}

locals {
  oci            = data.vault_kv_secret_v2.oci.data
  compartment_id = local.oci.compartment_ocid

  wg_private_key     = var.wireguard_from_vault ? data.vault_kv_secret_v2.wg_cloud_edge[0].data["private_key"] : "ci-placeholder"
  wg_gateway_pub_key = var.wireguard_from_vault ? data.vault_kv_secret_v2.wg_gateway[0].data["public_key"] : "ci-placeholder"
}
