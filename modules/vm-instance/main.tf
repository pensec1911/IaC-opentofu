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
