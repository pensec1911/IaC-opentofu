locals {
  node = "pve03"
}

# Forgejo + Actions-Runner (Renovate laeuft als Job darauf). pve03, weil dort
# nur arrstack laeuft. Disk bewusst 30 GB: local-lvm ist thin (141 GB), arrstack
# kann seine 100 GB voll schreiben, das Template belegt ~1 GB real.
module "vm" {
  source = "../../modules/vm-instance"

  name        = "forgejo"
  node_name   = local.node
  template_id = var.template_ids[local.node]

  ip_address = "192.168.178.29/24"
  gateway    = "192.168.178.1"

  cpu_cores = 2
  memory_mb = 6144
  disk_size = 30

  ssh_public_key      = var.ssh_public_key
  salt_master_address = "192.168.178.28"
}
