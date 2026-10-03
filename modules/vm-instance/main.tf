locals {
  needs_salt_bootstrap = var.install_salt_master || var.salt_master_address != null

  # Fester File-ID-String statt Referenz auf die Snippet-Resource. vendor-data
  # wird nur beim ersten Boot gelesen — referenziert die VM die Resource
  # direkt, baut OpenTofu bei jeder Textaenderung am Bootstrap die komplette VM
  # neu, ohne dass das auf der laufenden VM irgendetwas bewirken wuerde.
  # Rebuild bei Bedarf bewusst ueber `tofu apply -replace=...`.
  salt_bootstrap_file_id = "${var.snippets_datastore_id}:snippets/${var.name}-salt-bootstrap.yaml"
}

resource "proxmox_virtual_environment_file" "salt_bootstrap" {
  count = local.needs_salt_bootstrap ? 1 : 0

  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name

  source_raw {
    file_name = "${var.name}-salt-bootstrap.yaml"
    data = templatefile("${path.module}/templates/salt-bootstrap.yaml.tftpl", {
      install_salt_master = var.install_salt_master
      has_minion          = var.salt_master_address != null
      salt_master_address = var.salt_master_address != null ? var.salt_master_address : ""
      salt_version_pin    = var.salt_version_pin
    })
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  # Ohne die Resource-Referenz in vendor_data_file_id muss die Reihenfolge
  # explizit sein: das Snippet muss hochgeladen sein, bevor die VM bootet.
  depends_on = [proxmox_virtual_environment_file.salt_bootstrap]

  name      = var.name
  node_name = var.node_name
  vm_id     = var.vm_id

  clone {
    vm_id     = var.template_id
    node_name = coalesce(var.template_node_name, var.node_name)
    full      = var.full_clone
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
  }

  dynamic "disk" {
    for_each = var.disk_size != null ? [1] : []
    content {
      datastore_id = "local-lvm"
      interface    = "scsi0"
      size         = var.disk_size
    }
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  initialization {
    vendor_data_file_id = local.needs_salt_bootstrap ? local.salt_bootstrap_file_id : null

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      username = var.ci_username
      keys     = [var.ssh_public_key]
    }
  }
}
