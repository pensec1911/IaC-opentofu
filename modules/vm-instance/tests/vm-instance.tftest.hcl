# Unit tests for the vm-instance module. Fully offline: mock_provider means
# no real Proxmox endpoint or credentials are needed to run `tofu test` here.

mock_provider "proxmox" {}

variables {
  name           = "test-vm"
  node_name      = "pve01"
  template_id    = 9000
  ip_address     = "10.0.0.50/24"
  gateway        = "10.0.0.1"
  ssh_public_key = "ssh-ed25519 AAAAtestkey"
}

run "defaults_apply_expected_cpu_memory_and_clone_mode" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.cpu[0].cores == 2
    error_message = "Default cpu_cores should be 2"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.memory[0].dedicated == 2048
    error_message = "Default memory_mb should be 2048"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.clone[0].full == true
    error_message = "full_clone should default to true"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.initialization[0].user_account[0].username == "debian"
    error_message = "ci_username should default to debian"
  }
}

run "disk_block_present_when_disk_size_set" {
  command = plan

  variables {
    disk_size = 32
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this.disk) == 1
    error_message = "A disk block should be created when disk_size is set"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].size == 32
    error_message = "Disk size should match the disk_size variable"
  }
}

run "disk_block_omitted_when_disk_size_null" {
  command = plan

  variables {
    disk_size = null
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this.disk) == 0
    error_message = "No disk block should be created when disk_size is null (template disk size is inherited)"
  }
}

run "vlan_untagged_by_default" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].vlan_id == null
    error_message = "vlan_id should default to null (untagged, flat network)"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].bridge == "vmbr0"
    error_message = "bridge should default to vmbr0"
  }
}

run "vlan_tag_applied_when_set" {
  command = plan

  variables {
    vlan_id = 40
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.network_device[0].vlan_id == 40
    error_message = "vlan_id should be passed through to the network_device block"
  }
}

run "template_node_name_falls_back_to_node_name" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.this.clone[0].node_name == var.node_name
    error_message = "clone.node_name should default to node_name when template_node_name is not set"
  }
}

run "template_node_name_override_is_respected" {
  command = plan

  variables {
    template_node_name = "pve02"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.clone[0].node_name == "pve02"
    error_message = "clone.node_name should use template_node_name when it is set"
  }
}

run "no_salt_bootstrap_snippet_by_default" {
  command = plan

  # vendor_data_file_id is optional+computed, so mock_provider fills it in
  # regardless of what our config says — the resource count is the real signal.
  assert {
    condition     = length(proxmox_virtual_environment_file.salt_bootstrap) == 0
    error_message = "No cloud-init snippet should be created when Salt is not configured"
  }
}

run "installs_salt_minion_when_master_address_set" {
  command = plan

  variables {
    salt_master_address = "10.0.0.99"
  }

  override_resource {
    target = proxmox_virtual_environment_file.salt_bootstrap
    values = {
      id = "local:snippets/test-vm-salt-bootstrap.yaml"
    }
  }

  assert {
    condition     = length(proxmox_virtual_environment_file.salt_bootstrap) == 1
    error_message = "A cloud-init snippet should be created when salt_master_address is set"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.initialization[0].vendor_data_file_id != null
    error_message = "vendor_data_file_id should be set when Salt bootstrap is needed"
  }

  assert {
    condition     = strcontains(proxmox_virtual_environment_file.salt_bootstrap[0].source_raw[0].data, "master: 10.0.0.99")
    error_message = "Rendered cloud-init should point the minion at the configured master address"
  }

  assert {
    condition     = !strcontains(proxmox_virtual_environment_file.salt_bootstrap[0].source_raw[0].data, "salt-master")
    error_message = "salt-master package should not be installed when only salt_master_address is set"
  }
}

run "installs_salt_master_when_requested" {
  command = plan

  variables {
    install_salt_master = true
  }

  override_resource {
    target = proxmox_virtual_environment_file.salt_bootstrap
    values = {
      id = "local:snippets/test-vm-salt-bootstrap.yaml"
    }
  }

  assert {
    condition     = strcontains(proxmox_virtual_environment_file.salt_bootstrap[0].source_raw[0].data, "salt-master")
    error_message = "Rendered cloud-init should install salt-master when install_salt_master is true"
  }

  assert {
    condition     = strcontains(proxmox_virtual_environment_file.salt_bootstrap[0].source_raw[0].data, "auto_accept: true")
    error_message = "Master should be configured to auto-accept minion keys"
  }
}
