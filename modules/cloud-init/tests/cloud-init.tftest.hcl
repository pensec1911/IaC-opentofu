# Offline, keine Provider. Prueft vor allem, dass das Bootstrap ohne die
# Netz-Optionen byte-gleich zum frueheren modules/vm-instance-Template bleibt —
# sonst laedt der naechste Apply alle Snippets neu (ohne VM-Rebuild, aber
# unnoetig) und der Drift-Check meldet sie.

run "minion_only_matches_previous_template" {
  command = plan

  variables {
    salt_master_address = "192.168.178.28"
  }

  assert {
    condition = output.rendered == templatefile("${path.module}/tests/previous-bootstrap.yaml.tftpl", {
      install_salt_master = false
      has_minion          = true
      salt_master_address = "192.168.178.28"
      salt_version_pin    = "3008.*"
    })
    error_message = "Ohne Netz-Optionen muss das Bootstrap byte-gleich zum bisherigen bleiben"
  }
}

run "master_no_longer_auto_accepts" {
  command = plan

  variables {
    install_salt_master = true
  }

  assert {
    condition     = strcontains(output.rendered, "auto_accept: false") && !strcontains(output.rendered, "auto_accept: true")
    error_message = "Ein neu gebauter Master darf Minion-Keys nicht automatisch akzeptieren"
  }
}

run "wireguard_forwarding_nftables_and_minion_id" {
  command = plan

  variables {
    salt_master_address   = "192.168.178.28"
    minion_id             = "cloud-edge"
    wireguard_private_key = "test-private-key"
    ip_forward            = true
    nftables              = "table inet host\ndelete table inet host\ntable inet host {\n}\n"
    wireguard = {
      address     = "10.99.0.1/24"
      listen_port = 51820
      peers = [{
        public_key  = "test-peer-key"
        allowed_ips = ["10.99.0.2/32", "192.168.178.0/24"]
      }]
    }
  }

  assert {
    condition     = strcontains(output.rendered, "PrivateKey = test-private-key") && strcontains(output.rendered, "AllowedIPs = 10.99.0.2/32, 192.168.178.0/24")
    error_message = "wg0.conf muss Key und AllowedIPs enthalten"
  }

  assert {
    condition     = strcontains(output.rendered, "ListenPort = 51820") && !strcontains(output.rendered, "Endpoint =")
    error_message = "Server-Seite: ListenPort ja, Endpoint nein"
  }

  assert {
    condition     = strcontains(output.rendered, "systemctl enable --now wg-quick@wg0") && strcontains(output.rendered, "net.ipv4.ip_forward = 1") && strcontains(output.rendered, "      delete table inet host")
    error_message = "wg-quick, Forwarding und der eingerueckte nft-Regelsatz fehlen"
  }

  assert {
    condition     = strcontains(output.rendered, "path: /etc/salt/minion_id\n    content: cloud-edge")
    error_message = "minion_id muss gesetzt werden"
  }

  assert {
    condition     = yamldecode(output.rendered).packages == ["curl", "gnupg", "wireguard-tools", "nftables"]
    error_message = "Gerendertes cloud-config muss gueltiges YAML mit den Zusatzpaketen sein"
  }
}

run "client_side_has_endpoint_and_keepalive" {
  command = plan

  variables {
    salt_master_address   = "192.168.178.28"
    wireguard_private_key = "test-private-key"
    wireguard = {
      address = "10.99.0.2/24"
      peers = [{
        public_key  = "test-peer-key"
        allowed_ips = ["10.99.0.1/32"]
        endpoint    = "198.51.100.1:51820"
        keepalive   = 25
      }]
    }
  }

  assert {
    condition     = strcontains(output.rendered, "Endpoint = 198.51.100.1:51820") && strcontains(output.rendered, "PersistentKeepalive = 25") && !strcontains(output.rendered, "ListenPort")
    error_message = "Client-Seite: Endpoint + Keepalive, kein ListenPort"
  }
}
