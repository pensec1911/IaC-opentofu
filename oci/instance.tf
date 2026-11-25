# cloud-edge: Headscale + eingebauter DERP-Relay (IaC-salt formulas/headscale)
# und WireGuard-Server fuer den Verwaltungstunnel zu gateway (10.99.0.0/24).
# Salt, Backup und Monitoring laufen nur durch diesen Tunnel.
locals {
  shape = "VM.Standard.A1.Flex"
  # Always Free: zusammen max. 4 OCPU / 24 GB A1, 200 GB Block Storage.
  ocpus          = 1
  memory_gb      = 6
  boot_volume_gb = 50

  wg_address = "10.99.0.1/24"
  wg_port    = 51820
  lan_cidr   = "192.168.178.0/24"
  monitoring = "192.168.178.25"

  # Eigene Tabelle statt `flush ruleset`: ein Reload laesst die Regeln von
  # netavark (Podman) stehen. Nur input wird gefiltert; veroeffentlichte
  # Container-Ports laufen per DNAT ueber forward und sind schon durch die
  # NSG begrenzt.
  nftables = <<-NFT
    #!/usr/sbin/nft -f
    table inet host
    delete table inet host
    table inet host {
      chain input {
        type filter hook input priority filter; policy drop;
        ct state established,related accept
        ct state invalid drop
        iif "lo" accept
        meta l4proto { icmp, ipv6-icmp } accept
        udp sport 67 udp dport 68 accept
        tcp dport 443 accept
        udp dport { 3478, ${local.wg_port} } accept
        iifname "wg0" ip saddr ${local.lan_cidr} tcp dport 22 accept
        iifname "wg0" ip saddr ${local.monitoring} tcp dport { 9100, 8088, 9090 } accept
      }
    }
  NFT
}

module "cloud_init" {
  source = "../modules/cloud-init"

  salt_master_address   = var.salt_master_address
  minion_id             = "cloud-edge"
  wireguard_private_key = local.wg_private_key
  nftables              = local.nftables
  wireguard = {
    address     = local.wg_address
    listen_port = local.wg_port
    peers = [{
      public_key = local.wg_gateway_pub_key
      # gateway selbst + das LAN dahinter (Master, NAS, Loki, ...). Die
      # Freigaben im Einzelnen macht gateway's nftables.
      allowed_ips = ["10.99.0.2/32", local.lan_cidr]
    }]
  }
}

data "oci_identity_availability_domains" "this" {
  compartment_id = local.oci.tenancy_ocid
}

resource "oci_core_instance" "cloud_edge" {
  depends_on = [
    oci_core_compute_image_capability_schema.debian,
    oci_core_shape_management.debian_a1,
  ]

  compartment_id      = local.compartment_id
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[var.availability_domain_index].name
  display_name        = "cloud-edge"
  shape               = local.shape

  shape_config {
    ocpus         = local.ocpus
    memory_in_gbs = local.memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = local.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = false # reservierte IP unten
    hostname_label   = "cloud-edge"
    nsg_ids          = [oci_core_network_security_group.cloud_edge.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(module.cloud_init.rendered)
  }

  # Nur IMDSv2 (Header-Pflicht). Die Metadaten enthalten den privaten
  # WireGuard-Key und sind fuer jeden lokalen Prozess lesbar (IaC-salt
  # known-issues).
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  # user_data wirkt nur beim ersten Boot (wie das Proxmox-Snippet): eine
  # Aenderung am Bootstrap baut die VM nicht neu. Rebuild bewusst per
  # `tofu apply -replace=oci_core_instance.cloud_edge`.
  lifecycle {
    ignore_changes = [metadata["user_data"]]
  }
}

data "oci_core_vnic_attachments" "cloud_edge" {
  compartment_id = local.compartment_id
  instance_id    = oci_core_instance.cloud_edge.id
}

data "oci_core_private_ips" "cloud_edge" {
  vnic_id = data.oci_core_vnic_attachments.cloud_edge.vnic_attachments[0].vnic_id
}

# Reserviert: ueberlebt Stop/Start und einen Rebuild der Instanz — hs.<domain>
# (manuell bei Porkbun) und der WireGuard-Endpoint von gateway zeigen darauf.
resource "oci_core_public_ip" "cloud_edge" {
  compartment_id = local.compartment_id
  display_name   = "cloud-edge"
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.cloud_edge.private_ips[0].id

  lifecycle {
    prevent_destroy = true
  }
}
