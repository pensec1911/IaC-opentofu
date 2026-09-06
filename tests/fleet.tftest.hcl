# Whole-repo invariant checks. Both providers are fully mocked, so this
# needs no real Proxmox or OpenBao access to run `tofu test` from the repo root.

mock_provider "proxmox" {}
mock_provider "vault" {}

override_data {
  target = data.vault_kv_secret_v2.proxmox
  values = {
    data = {
      api_token = "mocked-token"
    }
  }
}

# The mocked download_file.id is a random string; the template VM's file_id
# validation requires the real "datastore:content-type/filename" shape.
override_resource {
  target = module.debian13_template.proxmox_download_file.cloudimage
  values = {
    id = "local:import/debian13-template.qcow2"
  }
}

variables {
  proxmox_endpoint  = "https://proxmox.invalid:8006"
  target_node       = "pve01"
  vm_ssh_public_key = "ssh-ed25519 AAAAtestkey"
  ssh_public_key    = "ssh-ed25519 AAAAtestkey"
  vault_role_id     = "test-role-id"
  vault_secret_id   = "test-secret-id"
}

run "fleet_plans_cleanly" {
  command = plan
}

run "no_two_vms_share_an_ip_address" {
  command = plan

  assert {
    condition     = length(distinct([for vm in output.vm_inventory : vm.ip])) == length(output.vm_inventory)
    error_message = "Two or more VMs are configured with the same ip_address — check vms/*/main.tf"
  }
}

run "no_node_exceeds_its_16gb_ram_budget" {
  command = plan

  assert {
    condition     = alltrue([for mb in values(output.memory_by_node_mb) : mb <= 16384])
    error_message = "A Proxmox node's combined VM memory_mb exceeds its 16GB capacity"
  }
}
