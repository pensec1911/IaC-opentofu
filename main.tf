module "debian13_template" {
  source = "./modules/vm-template"

  node_name     = "pve01"
  vm_id         = 9000
  template_name = "debian13-template"

  image_url = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  # image_checksum = "..." # optional: SHA512-Checksum eintragen für Reproduzierbarkeit
}
