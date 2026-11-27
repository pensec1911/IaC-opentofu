# Rendert das cloud-init fuer den ersten Boot. Genutzt von modules/vm-instance
# (Proxmox, als vendor-data-Snippet) und oci/ (OCI, als user_data). Keine
# Ressourcen, nur das Template — so bleiben Proxmox und OCI auf demselben
# Bootstrap (Salt-Repo, Pin, Minion-Config).
#
# Alle Netz-Optionen (wireguard, ip_forward, nftables) sind aus, solange sie
# null/false/leer sind; dann ist die Ausgabe byte-gleich mit dem frueheren
# salt-bootstrap.yaml.tftpl aus modules/vm-instance (tests/cloud-init.tftest.hcl).

variable "install_salt_master" {
  description = "salt-master installieren (nur der Master selbst)"
  type        = bool
  default     = false
}

variable "salt_master_address" {
  description = "IP/Hostname des Salt-Masters. null = kein salt-minion."
  type        = string
  default     = null
}

variable "salt_version_pin" {
  description = "apt-Pin fuer die Salt-Pakete (Broadcom-Repo)"
  type        = string
  default     = "3008.*"
}

variable "minion_id" {
  description = "Feste Minion-ID (/etc/salt/minion_id). null = Salt leitet sie vom Hostnamen ab (Proxmox: VM-Name). Auf OCI noetig, sonst wird der FQDN die ID."
  type        = string
  default     = null
}

variable "wireguard" {
  description = "Optionaler WireGuard-Tunnel wg0 (Netzdesign gehoert nach Tofu). peers[].endpoint nur auf der Seite, die die Verbindung aufbaut."
  type = object({
    address     = string
    listen_port = optional(number)
    # Ohne MTU leitet wg-quick sie vom Uplink ab: auf OCI (Jumbo-VNIC, 9000)
    # wird das 8920, die Strecke nach Hause traegt aber nur ~1500. Grosse
    # Pakete gehen dann verloren (NFS-Schreiben haengt, Lesen geht).
    mtu = optional(number)
    peers = list(object({
      public_key  = string
      allowed_ips = list(string)
      endpoint    = optional(string)
      keepalive   = optional(number)
    }))
  })
  default = null
}

variable "wireguard_private_key" {
  description = "Privater WireGuard-Key (aus OpenBao). Landet im Snippet bzw. in den Instance-Metadaten (IaC-salt known-issues)."
  type        = string
  default     = null
  sensitive   = true
}

variable "ip_forward" {
  description = "IPv4-Forwarding einschalten (Router/Gateway)"
  type        = bool
  default     = false
}

variable "nftables" {
  description = "Fertiger nft-Regelsatz fuer /etc/nftables.conf (null = nftables nicht anfassen). Eigene Tabelle statt `flush ruleset`, sonst loescht ein Reload die Regeln von netavark/Tailscale."
  type        = string
  default     = null
}
