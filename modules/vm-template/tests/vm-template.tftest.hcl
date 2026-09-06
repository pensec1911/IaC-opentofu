# Unit tests for the vm-template module. Fully offline via mock_provider.

mock_provider "proxmox" {}

# The mocked download_file.id is a random string; the template VM's file_id
# validation requires the real "datastore:content-type/filename" shape.
override_resource {
  target = proxmox_download_file.cloudimage
  values = {
    id = "local:import/test-template.qcow2"
  }
}

variables {
  node_name     = "pve01"
  vm_id         = 9000
  template_name = "test-template"
  image_url     = "https://example.invalid/debian-13-generic-amd64.qcow2"
}

run "template_flag_and_os_type_are_set" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.template.template == true
    error_message = "The resource must be marked as a template"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.template.operating_system[0].type == "l26"
    error_message = "operating_system.type should be l26"
  }
}

run "checksum_omitted_when_not_provided" {
  command = plan

  assert {
    condition     = proxmox_download_file.cloudimage.checksum == null
    error_message = "checksum should be null when image_checksum is not set"
  }

  assert {
    condition     = proxmox_download_file.cloudimage.checksum_algorithm == null
    error_message = "checksum_algorithm should be null when image_checksum is not set, even though it has a default"
  }
}

run "checksum_applied_when_provided" {
  command = plan

  variables {
    image_checksum = "deadbeef"
  }

  assert {
    condition     = proxmox_download_file.cloudimage.checksum == "deadbeef"
    error_message = "checksum should be passed through when image_checksum is set"
  }

  assert {
    condition     = proxmox_download_file.cloudimage.checksum_algorithm == "sha512"
    error_message = "checksum_algorithm should default to sha512 once a checksum is provided"
  }
}

run "rejects_vm_id_below_convention" {
  command = plan

  variables {
    vm_id = 100
  }

  expect_failures = [
    var.vm_id,
  ]
}
