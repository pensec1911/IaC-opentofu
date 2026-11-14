# Whole-repo invariant checks. Both providers are fully mocked, so this
# needs no real Proxmox or OpenBao access to run `tofu test` from the repo root.

mock_provider "proxmox" {}
mock_provider "vault" {}

# Gemockte IDs sind sonst Zufallsstrings; die NetBox-Ressourcen reichen sie als
# Zahlen (cluster_id, device_id, ...) weiter.
mock_provider "netbox" {
  mock_resource "netbox_tag" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_site" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_prefix" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_manufacturer" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_device_type" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_device_role" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_cluster_type" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_cluster" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_device" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_device_interface" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_device_primary_ip" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_virtual_machine" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_interface" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_ip_address" {
    defaults = { id = "1" }
  }
  mock_resource "netbox_primary_ip" {
    defaults = { id = "1" }
  }
}

override_data {
  target = data.vault_kv_secret_v2.proxmox
  values = {
    data = {
      api_token = "mocked-token"
    }
  }
}

override_data {
  target = data.vault_kv_secret_v2.netbox
  values = {
    data = {
      api_token = "mocked-token"
    }
  }
}

# The mocked download_file.id is a random string; the template VM's file_id
# validation requires the real "datastore:content-type/filename" shape.
# An unkeyed module address covers every for_each instance (pve01/02/03);
# override_resource rejects instance keys.
override_resource {
  target = module.debian13_template.proxmox_download_file.cloudimage
  values = {
    id = "local:import/debian13-template.qcow2"
  }
}

# Same issue for every VM's Salt-bootstrap cloud-init snippet: the mocked
# proxmox_virtual_environment_file.id needs to look like a real file_id for
# vendor_data_file_id's validation to accept it.
override_resource {
  target = module.jellyfin.module.vm.proxmox_virtual_environment_file.salt_bootstrap
  values = {
    id = "local:snippets/jellyfin-salt-bootstrap.yaml"
  }
}

override_resource {
  target = module.arrstack.module.vm.proxmox_virtual_environment_file.salt_bootstrap
  values = {
    id = "local:snippets/arrstack-salt-bootstrap.yaml"
  }
}

# wazuh ist in vms.tf auskommentiert.
#override_resource {
#  target = module.wazuh.module.vm.proxmox_virtual_environment_file.salt_bootstrap
#  values = {
#    id = "local:snippets/wazuh-salt-bootstrap.yaml"
#  }
#}

override_resource {
  target = module.monitoring.module.vm.proxmox_virtual_environment_file.salt_bootstrap
  values = {
    id = "local:snippets/monitoring-salt-bootstrap.yaml"
  }
}

override_resource {
  target = module.homepage.module.vm.proxmox_virtual_environment_file.salt_bootstrap
  values = {
    id = "local:snippets/homepage-salt-bootstrap.yaml"
  }
}

override_resource {
  target = module.forgejo.module.vm.proxmox_virtual_environment_file.salt_bootstrap
  values = {
    id = "local:snippets/forgejo-salt-bootstrap.yaml"
  }
}

override_resource {
  target = module.salt_master.module.vm.proxmox_virtual_environment_file.salt_bootstrap
  values = {
    id = "local:snippets/salt-master-salt-bootstrap.yaml"
  }
}

variables {
  proxmox_endpoint  = "https://proxmox.invalid:8006"
  target_node       = "pve01"
  vm_ssh_public_key = "ssh-ed25519 AAAAtestkey"
  ssh_public_key    = "ssh-ed25519 AAAAtestkey"
  vault_role_id     = "test-role-id"
  state_passphrase  = "test-passphrase-not-a-secret"
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

# Wie oben, aber inkl. der nicht von Tofu verwalteten VMs und der physischen
# Geraete — alles, was nach NetBox geht.
run "netbox_has_no_duplicate_ip_or_name" {
  command = plan

  assert {
    condition = length(distinct(concat(
      [for ip in netbox_ip_address.vm : ip.ip_address],
      [for ip in netbox_ip_address.device : ip.ip_address],
    ))) == length(netbox_ip_address.vm) + length(netbox_ip_address.device)
    error_message = "Two NetBox entries share an IP — check netbox.tf (netbox_unmanaged_vms, netbox_devices) against vms/*/main.tf"
  }

  assert {
    condition     = length(setintersection(keys(local.netbox_unmanaged_vms), keys(local.netbox_vms))) == length(local.netbox_unmanaged_vms) && length(local.netbox_vms) == length(local.vm_inventory) + length(local.netbox_unmanaged_vms)
    error_message = "A VM in netbox_unmanaged_vms is also managed by Tofu — remove it from netbox_unmanaged_vms"
  }
}
