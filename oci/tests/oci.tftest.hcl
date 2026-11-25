# Offline-Tests fuer oci/: OCI und OpenBao sind gemockt.

mock_provider "oci" {}
mock_provider "vault" {}

override_data {
  target = data.vault_kv_secret_v2.oci
  values = {
    data = {
      tenancy_ocid     = "ocid1.tenancy.oc1..test"
      user_ocid        = "ocid1.user.oc1..test"
      fingerprint      = "00:00"
      private_key      = "test-key"
      region           = "eu-frankfurt-1"
      compartment_ocid = "ocid1.compartment.oc1..test"
    }
  }
}

override_data {
  target = data.vault_kv_secret_v2.wg_cloud_edge
  values = {
    data = { private_key = "test-cloud-edge-private", public_key = "test-cloud-edge-public" }
  }
}

override_data {
  target = data.vault_kv_secret_v2.wg_gateway
  values = {
    data = { private_key = "test-gateway-private", public_key = "test-gateway-public" }
  }
}

override_data {
  target = data.oci_identity_availability_domains.this
  values = {
    availability_domains = [for n in ["AD-1", "AD-2", "AD-3"] : { name = n, compartment_id = "ocid1.tenancy.oc1..test", id = "ocid1.ad.oc1..${n}" }]
  }
}

override_data {
  target = data.oci_core_compute_global_image_capability_schemas.this
  values = {
    compute_global_image_capability_schemas = [{
      current_version_name = "test-version"
      compartment_id       = "ocid1.tenancy.oc1..test"
      defined_tags         = {}
      display_name         = "OCI.ComputeGlobalImageCapabilitySchema"
      freeform_tags        = {}
      id                   = "ocid1.schema.oc1..test"
      time_created         = "2026-01-01T00:00:00Z"
    }]
  }
}

override_data {
  target = data.oci_core_vnic_attachments.cloud_edge
  values = {
    vnic_attachments = [{ vnic_id = "ocid1.vnic.oc1..test" }]
  }
}

override_data {
  target = data.oci_core_private_ips.cloud_edge
  values = {
    private_ips = [{ id = "ocid1.privateip.oc1..test" }]
  }
}

override_data {
  target = data.oci_core_images.ubuntu
  values = {
    images = [{
      id                       = "ocid1.image.oc1..ubuntu"
      agent_features           = []
      base_image_id            = ""
      billable_size_in_gbs     = "0"
      compartment_id           = ""
      create_image_allowed     = true
      defined_tags             = {}
      display_name             = "Canonical-Ubuntu-24.04-aarch64"
      freeform_tags            = {}
      image_source_details     = []
      instance_id              = ""
      launch_mode              = "PARAVIRTUALIZED"
      launch_options           = []
      listing_type             = ""
      operating_system         = "Canonical Ubuntu"
      operating_system_version = "24.04"
      size_in_mbs              = "0"
      state                    = "AVAILABLE"
      time_created             = "2026-01-01T00:00:00Z"
    }]
  }
}

variables {
  state_passphrase = "test-passphrase-not-a-secret"
  vault_role_id    = "test-role-id"
  vault_secret_id  = "test-secret-id"
  ssh_public_key   = "ssh-ed25519 AAAAtestkey"
}

run "only_three_public_ports" {
  command = plan

  assert {
    condition = toset([for r in oci_core_network_security_group_security_rule.ingress : "${r.protocol}/${one(concat(
      [for o in r.tcp_options : o.destination_port_range[0].min],
      [for o in r.udp_options : o.destination_port_range[0].min],
    ))}"]) == toset(["6/443", "17/3478", "17/51820"])
    error_message = "Die NSG darf nur 443/tcp, 3478/udp und 51820/udp oeffnen"
  }

  assert {
    condition     = length(oci_core_default_security_list.this.ingress_security_rules) == 1 && one(oci_core_default_security_list.this.ingress_security_rules).protocol == "1"
    error_message = "Die Default-Security-List darf nur ICMP (Path MTU) erlauben — kein 22/tcp"
  }
}

run "stays_in_always_free" {
  command = plan

  assert {
    condition     = output.shape.shape == "VM.Standard.A1.Flex" && output.shape.ocpus <= 4 && output.shape.memory_gb <= 24 && output.shape.boot_volume_gb <= 200
    error_message = "cloud-edge muss im Always-Free-Kontingent bleiben (A1: 4 OCPU / 24 GB, 200 GB Block)"
  }

  assert {
    condition     = oci_core_instance.cloud_edge.create_vnic_details[0].assign_public_ip == "false" && oci_core_public_ip.cloud_edge.lifetime == "RESERVED"
    error_message = "Oeffentliche IP nur als reservierte IP, nicht ephemer"
  }

  assert {
    condition     = oci_core_instance.cloud_edge.instance_options[0].are_legacy_imds_endpoints_disabled == true
    error_message = "IMDSv1 muss aus sein"
  }
}

run "cloud_init_has_tunnel_and_minion" {
  command = plan

  assert {
    condition     = strcontains(module.cloud_init.rendered, "Address = 10.99.0.1/24") && strcontains(module.cloud_init.rendered, "PublicKey = test-gateway-public") && strcontains(module.cloud_init.rendered, "PrivateKey = test-cloud-edge-private")
    error_message = "wg0 muss 10.99.0.1 mit dem gateway-Peer sein"
  }

  assert {
    condition     = strcontains(module.cloud_init.rendered, "master: 192.168.178.28") && strcontains(module.cloud_init.rendered, "content: cloud-edge")
    error_message = "salt-minion muss auf den Master zeigen und die feste ID cloud-edge haben"
  }

  assert {
    condition     = length(regexall("(?m)^\\s*tcp dport 22 accept", module.cloud_init.rendered)) == 0 && strcontains(module.cloud_init.rendered, "iifname \"wg0\" ip saddr 192.168.178.0/24 tcp dport 22 accept")
    error_message = "SSH nur ueber wg0 aus dem LAN"
  }

  assert {
    condition     = startswith(one([for f in yamldecode(module.cloud_init.rendered).write_files : f.content if f.path == "/etc/nftables.conf"]), "#!/usr/sbin/nft -f\ntable inet host\n")
    error_message = "cloud-init muss gueltiges YAML sein und den nft-Regelsatz unveraendert nach /etc/nftables.conf schreiben"
  }
}

run "debian_import_by_default" {
  command = plan

  assert {
    condition     = length(oci_core_image.debian) == 1 && oci_core_image.debian[0].image_source_details[0].source_image_type == "QCOW2" && length(oci_core_shape_management.debian_a1) == 1
    error_message = "Standard ist das importierte Debian-13-Image mit A1-Freischaltung"
  }
}

run "ubuntu_fallback" {
  command = plan

  variables {
    use_platform_image = true
  }

  assert {
    condition     = length(oci_core_image.debian) == 0 && oci_core_instance.cloud_edge.source_details[0].source_id == "ocid1.image.oc1..ubuntu"
    error_message = "use_platform_image muss das Ubuntu-Plattform-Image nutzen und nichts importieren"
  }
}

run "ci_never_reads_wireguard_keys" {
  command = plan

  variables {
    wireguard_from_vault = false
  }

  assert {
    condition     = length(data.vault_kv_secret_v2.wg_cloud_edge) == 0 && strcontains(module.cloud_init.rendered, "PrivateKey = ci-placeholder")
    error_message = "Mit wireguard_from_vault=false darf kein WireGuard-Secret gelesen werden"
  }
}
