# Ein Template pro Node. Ohne Shared Storage muss ein Cross-Node-Clone die
# komplette Disk von pve01 auf den Ziel-Node migrieren — das lief beim Apply in
# den Provider-Timeout und hat halb fertige VMs hinterlassen (ohne Cloud-Init,
# also ohne IP und ohne Salt). Klont jede VM lokal auf ihrem eigenen Node,
# entfaellt der Migrationsschritt komplett.
# VM-IDs sind im Cluster eindeutig, darum pro Node eine eigene ID.
locals {
  template_nodes = {
    pve01 = 9000
    pve02 = 9001
    pve03 = 9002
  }
}

module "debian13_template" {
  source   = "./modules/vm-template"
  for_each = local.template_nodes

  node_name     = each.key
  vm_id         = each.value
  template_name = "debian13-template"

  image_url = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  # image_checksum = "..." # optional: SHA512-Checksum eintragen für Reproduzierbarkeit
}

# Das bestehende Template 9000 auf pve01 wandert in die for_each-Instanz,
# statt zerstoert und neu gebaut zu werden.
moved {
  from = module.debian13_template
  to   = module.debian13_template["pve01"]
}
