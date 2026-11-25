locals {
  rendered = templatefile("${path.module}/templates/bootstrap.yaml.tftpl", {
    install_salt_master   = var.install_salt_master
    has_minion            = var.salt_master_address != null
    salt_master_address   = var.salt_master_address != null ? var.salt_master_address : ""
    salt_version_pin      = var.salt_version_pin
    minion_id             = var.minion_id != null ? var.minion_id : ""
    wireguard             = var.wireguard
    wireguard_private_key = var.wireguard_private_key != null ? var.wireguard_private_key : ""
    ip_forward            = var.ip_forward
    nftables              = var.nftables != null ? trimspace(var.nftables) : ""
  })
}
