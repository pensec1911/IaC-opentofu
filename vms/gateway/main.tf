# gateway: WireGuard-Client zu cloud-edge (OCI) fuer den Verwaltungstunnel
# 10.99.0.0/24 und spaeter Tailscale-Subnet-Router (IaC-salt formulas/tailscale).
# Die FRITZ!Box routet 10.99.0.0/24 hierher (statische Route, manuell).
#
# Firewall nur hier: was cloud-edge im LAN erreichen darf, steht in der
# forward-Chain. Aenderungen wirken erst nach einem Rebuild (vendor-data nur
# beim ersten Boot): `tofu apply -replace='module.gateway.module.vm.proxmox_virtual_environment_file.salt_bootstrap_secret[0]' -replace='module.gateway.module.vm.proxmox_virtual_environment_vm.this'`
# — gateway ist zustandsarm, Tailscale braucht danach einen neuen Pre-Auth-Key.
locals {
  node = "pve01"

  lan_cidr   = "192.168.178.0/24"
  wg_address = "10.99.0.2/24"
  wg_port    = 51820
  cloud_edge = "10.99.0.1"
  # Reservierte OCI-IP (oci/ Output public_ip, prevent_destroy) — fest statt
  # terraform_remote_state, damit dieses Root-Modul nicht vom oci-State abhaengt.
  cloud_edge_endpoint = "92.6.177.252"

  salt_master = "192.168.178.28"
  nas         = "192.168.178.10"
  monitoring  = "192.168.178.25"
  jellyfin    = "192.168.178.24" # Healthchecks :8000
  forgejo     = "192.168.178.29" # PatchMon :3001

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
        ip saddr ${local.lan_cidr} tcp dport 22 accept
        ip saddr ${local.monitoring} tcp dport 9100 accept
        ip saddr ${local.cloud_edge_endpoint} udp dport ${local.wg_port} accept
        iifname "wg0" ip saddr ${local.cloud_edge} accept
        # Tailscale: direkte Verbindungen; was ueber das Tailnet rein darf,
        # regelt die Headscale-ACL.
        udp dport 41641 accept
        iifname "tailscale0" accept
      }

      chain forward {
        type filter hook forward priority filter; policy drop;
        ct state established,related accept
        ct state invalid drop

        # cloud-edge -> LAN: nur Salt, NFS (Backups), Loki, Healthchecks, PatchMon.
        iifname "wg0" ip saddr ${local.cloud_edge} ip daddr ${local.salt_master} tcp dport { 4505, 4506 } accept
        iifname "wg0" ip saddr ${local.cloud_edge} ip daddr ${local.nas} tcp dport 2049 accept
        iifname "wg0" ip saddr ${local.cloud_edge} ip daddr ${local.monitoring} tcp dport 3100 accept
        iifname "wg0" ip saddr ${local.cloud_edge} ip daddr ${local.jellyfin} tcp dport 8000 accept
        iifname "wg0" ip saddr ${local.cloud_edge} ip daddr ${local.forgejo} tcp dport 3001 accept

        # LAN -> cloud-edge: Prometheus-Scrapes (node-exporter, cadvisor,
        # headscale metrics) und SSH aus dem LAN.
        iifname "eth0" ip saddr ${local.monitoring} ip daddr ${local.cloud_edge} tcp dport { 9100, 8088, 9090 } accept
        iifname "eth0" ip saddr ${local.lan_cidr} ip daddr ${local.cloud_edge} tcp dport 22 accept

        # Tailnet -> LAN (Subnet-Router). Feinsteuerung: Headscale-ACL.
        iifname "tailscale0" oifname "eth0" accept
      }
    }
  NFT
}

module "vm" {
  source = "../../modules/vm-instance"

  name        = "gateway"
  node_name   = local.node
  template_id = var.template_ids[local.node]

  ip_address = "192.168.178.31/24"
  gateway    = "192.168.178.1"

  cpu_cores = 1
  memory_mb = 1024
  disk_size = 20

  ssh_public_key      = var.ssh_public_key
  salt_master_address = local.salt_master

  ip_forward            = true
  nftables              = local.nftables
  wireguard_private_key = var.wireguard_private_key
  wireguard = {
    address     = local.wg_address
    listen_port = local.wg_port
    peers = [{
      public_key  = var.cloud_edge_public_key
      allowed_ips = ["${local.cloud_edge}/32"]
      endpoint    = "${local.cloud_edge_endpoint}:${local.wg_port}"
      keepalive   = 25
    }]
  }
}
