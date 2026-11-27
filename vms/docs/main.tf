# docs: Paperless-ngx, spaeter Nextcloud auf derselben VM (IaC-salt
# .claude/docs/roadmap.md "Next up"). Normale LAN-VM. Dokumente liegen auf der
# NAS (NFS-Dataset /mnt/pool01/documents/paperless, nur fuer .21 freigegeben),
# lokal nur Postgres, Suchindex, Redis und Images. RAM schon fuer beide Apps.
locals {
  node = "pve01"
}

module "vm" {
  source = "../../modules/vm-instance"

  name      = "docs"
  node_name = local.node
  # Feste ID: die Firewall-Regeln (firewall.tf) haengen an ihr.
  vm_id       = 110
  template_id = var.template_ids[local.node]

  ip_address = "192.168.178.21/24"
  gateway    = "192.168.178.1"

  # OCR (Paperless) laeuft in Schueben, 4 Kerne halten das kurz.
  cpu_cores = 4
  memory_mb = 6144
  disk_size = 40

  ssh_public_key      = var.ssh_public_key
  salt_master_address = "192.168.178.28"
}
