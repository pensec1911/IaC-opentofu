# Proxmox-Firewall (Schritt 7 des Zero-Trust-Plans): pro VM eingehend DROP,
# erlaubt nur, was unten steht. Ausgehend bleibt alles offen.
#
# Grundsatz: Web-UIs nur noch von edge (Caddy + Authentik) und monitoring
# (Blackbox-Probes direkt auf den Upstream). Maschine-zu-Maschine (Salt,
# Loki, Healthchecks, PatchMon, Prometheus) bleibt offen, ebenso SSH aus dem
# LAN. Der Tailnet-Verkehr kommt per SNAT von gateway (.31), liegt also im
# LAN-Netz; was das Tailnet darf, entscheidet die Headscale-ACL (IaC-salt
# pillar/headscale.sls). cloud-edge (10.99.0.1) kommt durch den Tunnel ohne
# SNAT — als eigene Quelle bei den Diensten, die es nutzt.
#
# Die Firewall des Clusters wird eingeschaltet, aber mit input_policy ACCEPT:
# die PVE-Hosts selbst (8006, 22, Corosync) bleiben unberuehrt. Gefiltert
# werden nur die VMs hier unten. Nicht dabei: openbao (nicht von Tofu
# verwaltet, netbox.tf).
#
# Notzugang, falls eine Regel etwas aussperrt: Proxmox-UI/API sind nicht
# betroffen -> Regel hier fixen und apply, oder im UI die Firewall der VM
# ausschalten (VM -> Firewall -> Options -> Firewall: No).

locals {
  fw_lan        = "192.168.178.0/24"
  fw_cloud_edge = "10.99.0.1"
  fw_edge       = "192.168.178.30"
  fw_monitoring = "192.168.178.25"
  fw_homepage   = "192.168.178.23"
  fw_salt       = "192.168.178.28"
  fw_forgejo    = "192.168.178.29"
  fw_gateway    = "192.168.178.31"
  fw_truenas    = "192.168.178.10"

  # Alle Salt-Minions (LAN + cloud-edge durch den Tunnel).
  fw_minions = "${local.fw_lan},${local.fw_cloud_edge}"
  # Wer Web-UIs direkt erreichen darf: Caddy und die Blackbox-Probes.
  fw_web = "${local.fw_edge},${local.fw_monitoring}"

  # Jede Regel mit allen Feldern (Tofu braucht einheitliche Objekttypen).
  # dest nur bei gateway: Verkehr, den er weiterleitet (10.99.0.0/24).
  fw_common = [
    { comment = "SSH aus dem LAN (Tailnet ueber gateway-SNAT)", proto = "tcp", dport = "22", source = local.fw_lan, dest = null },
    { comment = "Prometheus: node-exporter, cAdvisor", proto = "tcp", dport = "9100,8088", source = local.fw_monitoring, dest = null },
    { comment = "Ping aus dem LAN", proto = "icmp", dport = null, source = local.fw_lan, dest = null },
  ]

  fw_rules = {
    arrstack = [
      { comment = "Web-UIs: Seerr, Sonarr, Radarr, Prowlarr, Bazarr, qBittorrent, slskd", proto = "tcp", dport = "5055,8989,7878,9696,6767,8080,5030", source = local.fw_web, dest = null },
    ]
    homepage = [
      { comment = "homepage", proto = "tcp", dport = "3000", source = local.fw_web, dest = null },
    ]
    jellyfin = [
      { comment = "Jellyfin fuer TV/Apps im LAN", proto = "tcp", dport = "8096", source = local.fw_lan, dest = null },
      { comment = "Jellyfin Client-Discovery", proto = "udp", dport = "7359", source = local.fw_lan, dest = null },
      { comment = "ntfy (Alertmanager, Skripte, Caddy push.*)", proto = "tcp", dport = "8090", source = local.fw_minions, dest = null },
      { comment = "Healthchecks-Pings aller Minions + UI", proto = "tcp", dport = "8000", source = local.fw_minions, dest = null },
    ]
    monitoring = [
      { comment = "Web-UIs: Grafana, Prometheus, Alertmanager, CyberChef, IT-Tools", proto = "tcp", dport = "3000,9090,9093,8081,8082", source = local.fw_edge, dest = null },
      { comment = "homepage-Widget -> Prometheus", proto = "tcp", dport = "9090", source = local.fw_homepage, dest = null },
      { comment = "Prometheus/Alertmanager-API: /homelab-status, capacity.py (Tailnet via gateway), salt-master", proto = "tcp", dport = "9090,9093", source = "${local.fw_gateway},${local.fw_salt}", dest = null },
      { comment = "Loki: alloy auf allen Minions", proto = "tcp", dport = "3100", source = local.fw_minions, dest = null },
      { comment = "TrueNAS Graphite -> graphite_exporter", proto = "tcp", dport = "9109", source = local.fw_truenas, dest = null },
    ]
    salt_master = [
      { comment = "Salt publish/return von allen Minions", proto = "tcp", dport = "4505,4506", source = local.fw_minions, dest = null },
      { comment = "salt-api: Alertmanager, Forgejo-Webhook", proto = "tcp", dport = "8000", source = "${local.fw_monitoring},${local.fw_forgejo}", dest = null },
    ]
    forgejo = [
      { comment = "Forgejo Web (Caddy, Blackbox)", proto = "tcp", dport = "3000", source = local.fw_web, dest = null },
      { comment = "git ueber SSH (gitfs vom Master, Admins)", proto = "tcp", dport = "2222", source = local.fw_lan, dest = null },
      { comment = "NetBox (Caddy, Blackbox, Tofu ueber Tailnet)", proto = "tcp", dport = "8000", source = "${local.fw_web},${local.fw_gateway}", dest = null },
      { comment = "tofu-state Postgres (Tofu ueber Tailnet)", proto = "tcp", dport = "5432", source = local.fw_gateway, dest = null },
      { comment = "PatchMon: Agents aller Minions + UI", proto = "tcp", dport = "3001", source = local.fw_minions, dest = null },
    ]
    wazuh = [
      { comment = "Wazuh-Dashboard (Caddy, Blackbox)", proto = "tcp", dport = "443", source = local.fw_web, dest = null },
      { comment = "Wazuh-Agents: Events + Enrollment (LAN; cloud-edge nicht, gateway leitet 1514/1515 nicht weiter)", proto = "tcp", dport = "1514,1515", source = local.fw_lan, dest = null },
    ]
    edge = [
      { comment = "Caddy HTTPS/HTTP fuer alle", proto = "tcp", dport = "80,443", source = null, dest = null },
      { comment = "Prometheus: Caddy- und Authentik-Metriken", proto = "tcp", dport = "9180,9300", source = local.fw_monitoring, dest = null },
    ]
    docs = [
      { comment = "Paperless-ngx (Caddy, Blackbox)", proto = "tcp", dport = "8000", source = local.fw_web, dest = null },
    ]
    gateway = [
      { comment = "WireGuard von cloud-edge (Portweiterleitung FRITZ!Box)", proto = "udp", dport = "51820", source = null, dest = null },
      { comment = "Tailscale direkte Verbindungen", proto = "udp", dport = "41641", source = null, dest = null },
      { comment = "LAN -> cloud-edge weiterleiten (nftables auf gateway filtert)", proto = null, dport = null, source = local.fw_lan, dest = "10.99.0.0/24" },
    ]
  }

  fw_vms = {
    arrstack    = module.arrstack
    homepage    = module.homepage
    jellyfin    = module.jellyfin
    monitoring  = module.monitoring
    salt_master = module.salt_master
    forgejo     = module.forgejo
    edge        = module.edge
    gateway     = module.gateway
    wazuh       = module.wazuh
    docs        = module.docs
  }
}

resource "proxmox_virtual_environment_firewall_rules" "vm" {
  for_each = local.fw_vms

  node_name = each.value.node_name
  vm_id     = each.value.vm_id

  dynamic "rule" {
    for_each = concat(local.fw_common, local.fw_rules[each.key])
    content {
      type    = "in"
      action  = "ACCEPT"
      comment = rule.value.comment
      proto   = rule.value.proto
      dport   = rule.value.dport
      source  = rule.value.source
      dest    = rule.value.dest
    }
  }
}

# Erst die Regeln, dann scharf schalten.
resource "proxmox_virtual_environment_firewall_options" "vm" {
  for_each   = local.fw_vms
  depends_on = [proxmox_virtual_environment_firewall_rules.vm]

  node_name = each.value.node_name
  vm_id     = each.value.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  # Ausgehende Pakete nur mit der MAC der VM (Standard); keine IP-Filter:
  # gateway leitet Pakete mit fremden Quell-IPs weiter (10.99.0.1).
  macfilter = true
  ipfilter  = false
  dhcp      = false
}

# Der Hauptschalter. input_policy ACCEPT: die PVE-Hosts bleiben offen.
resource "proxmox_virtual_environment_cluster_firewall" "this" {
  depends_on = [proxmox_virtual_environment_firewall_options.vm]

  enabled        = true
  input_policy   = "ACCEPT"
  output_policy  = "ACCEPT"
  forward_policy = "ACCEPT"
}
