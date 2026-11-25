# Ein oeffentliches Subnetz. Eingehend offen ist nur, was die NSG erlaubt:
# 443/tcp (Headscale + DERP, ACME per TLS-ALPN-01), 3478/udp (STUN),
# 51820/udp (WireGuard von gateway). Kein SSH von aussen — Notzugang ist
# die Serial Console (README "OCI").
locals {
  vcn_cidr    = "10.98.0.0/16" # bewusst nicht 10.99.0.0/24 (Tunnel) oder das LAN
  subnet_cidr = "10.98.1.0/24"

  public_ingress = {
    https     = { protocol = "6", port = 443 }    # tcp
    stun      = { protocol = "17", port = 3478 }  # udp
    wireguard = { protocol = "17", port = 51820 } # udp
  }
}

resource "oci_core_vcn" "this" {
  compartment_id = local.compartment_id
  display_name   = "homelab"
  cidr_blocks    = [local.vcn_cidr]
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "homelab-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "homelab-public"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

# Die Default-Security-List einer neuen VCN erlaubt 22/tcp von 0.0.0.0/0.
# Uebernommen und auf Egress + Path-MTU-ICMP reduziert; Ports oeffnet nur
# die NSG unten.
resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id
  display_name               = "homelab-default"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1" # icmp: fragmentation needed (Path MTU, WireGuard)
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = local.compartment_id
  vcn_id            = oci_core_vcn.this.id
  cidr_block        = local.subnet_cidr
  display_name      = "homelab-public"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_default_security_list.this.id]
}

resource "oci_core_network_security_group" "cloud_edge" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "cloud-edge"
}

resource "oci_core_network_security_group_security_rule" "ingress" {
  for_each = local.public_ingress

  network_security_group_id = oci_core_network_security_group.cloud_edge.id
  direction                 = "INGRESS"
  protocol                  = each.value.protocol
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = each.key

  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" ? [1] : []
    content {
      destination_port_range {
        min = each.value.port
        max = each.value.port
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol == "17" ? [1] : []
    content {
      destination_port_range {
        min = each.value.port
        max = each.value.port
      }
    }
  }
}

resource "oci_core_network_security_group_security_rule" "egress" {
  network_security_group_id = oci_core_network_security_group.cloud_edge.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}
