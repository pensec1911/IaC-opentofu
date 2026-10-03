resource "proxmox_download_file" "cloudimage" {
  content_type = "import"
  datastore_id = var.download_datastore_id
  node_name    = var.node_name
  url          = var.image_url
  file_name    = "${var.template_name}.qcow2"

  checksum           = var.image_checksum
  checksum_algorithm = var.image_checksum != null ? var.image_checksum_algorithm : null
  overwrite          = var.overwrite
}

resource "proxmox_virtual_environment_vm" "template" {
  name      = var.template_name
  node_name = var.node_name
  vm_id     = var.vm_id
  template  = true

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
  }

  # import_from laesst Proxmox die Disk serverseitig per API importieren
  # (import-from, PVE >= 8). file_id wuerde den Provider stattdessen per SSH als
  # root auf den Node schicken und "qm importdisk" aufrufen — das braucht
  # Root-SSH-Keys auf jedem Node und ist hier nie eingerichtet gewesen.
  disk {
    datastore_id = var.disk_datastore_id
    import_from  = proxmox_download_file.cloudimage.id
    interface    = "scsi0"
    size         = var.disk_size
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {}

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [network_device]
  }
}
