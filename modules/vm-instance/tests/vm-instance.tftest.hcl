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
