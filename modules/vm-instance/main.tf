locals {
  needs_salt_bootstrap = var.install_salt_master || var.salt_master_address != null
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
    })
  }
}

resource "proxmox_virtual_environment_vm" "this" {
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
    vendor_data_file_id = local.needs_salt_bootstrap ? proxmox_virtual_environment_file.salt_bootstrap[0].id : null

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
