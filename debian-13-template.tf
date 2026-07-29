resource "proxmox_virtual_environment_download_file" "debian13_cloudimage" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "pve01"
  url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  file_name    = "debian-13-generic-amd64.qcow2"
}

resource "proxmox_virtual_environment_vm" "debian13_template" {
  name      = "debian13-template"
  node_name = "pve01"
  template  = true
  vm_id = 9000

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.debian13_cloudimage.id
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    # leer/minimal, wird beim Clone überschrieben
  }

  operating_system {
    type = "l26"
  }

  # verhindert dass Tofu bei jedem Apply versucht die Template-VM neu zu starten
  lifecycle {
    ignore_changes = [network_device]
  }
}
