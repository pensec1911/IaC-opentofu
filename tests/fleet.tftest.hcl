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

override_data {
  target = data.vault_kv_secret_v2.wg_gateway
  values = {
    data = {
      private_key = "mocked-gateway-private-key"
      public_key  = "mocked-gateway-public-key"
    }
  }
}

override_data {
  target = data.vault_kv_secret_v2.wg_cloud_edge
  values = {
    data = {
      private_key = "mocked-cloud-edge-private-key"
      public_key  = "mocked-cloud-edge-public-key"
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

override_resource {
  target = module.wazuh.module.vm.proxmox_virtual_environment_file.salt_bootstrap
  values = {
    id = "local:snippets/wazuh-salt-bootstrap.yaml"
  }
}

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

override_resource {
  target = module.edge.module.vm.proxmox_virtual_environment_file.salt_bootstrap
  values = {
    id = "local:snippets/edge-salt-bootstrap.yaml"
  }
}

override_resource {
  target = module.docs.module.vm.proxmox_virtual_environment_file.salt_bootstrap
  values = {
    id = "local:snippets/docs-salt-bootstrap.yaml"
  }
}

# gateway's Snippet traegt den WireGuard-Key -> eigene Resource (modules/vm-instance).
override_resource {
  target = module.gateway.module.vm.proxmox_virtual_environment_file.salt_bootstrap_secret
  values = {
    id = "local:snippets/gateway-salt-bootstrap.yaml"
  }
}

variables {
  proxmox_endpoint = "https://proxmox.invalid:8006"
  target_node      = "pve01"
  ssh_public_key   = "ssh-ed25519 AAAAtestkey"
  vault_role_id    = "test-role-id"
  state_passphrase = "test-passphrase-not-a-secret"
  vault_secret_id  = "test-secret-id"
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

run "no_node_exceeds_its_ram" {
  command = plan

  assert {
    condition     = alltrue([for node, mb in output.memory_by_node_mb : contains(keys(output.node_memory_mb), node)])
    error_message = "A VM sits on a Proxmox node missing from node_memory_mb (outputs.tf)"
  }

  assert {
    condition     = alltrue([for node, mb in output.memory_by_node_mb : mb <= lookup(output.node_memory_mb, node, 0)])
    error_message = "A Proxmox node's combined VM memory_mb exceeds its physical RAM (node_memory_mb in outputs.tf)"
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

# Der Verwaltungstunnel (gateway <-> cloud-edge) darf weder mit dem LAN noch
# mit dem OCI-VCN (oci/, 10.98.0.0/16) kollidieren, sonst routet gateway falsch.
run "wireguard_net_does_not_collide_with_lan" {
  command = plan

  assert {
    condition = alltrue([
      for vm in output.vm_inventory :
      cidrhost("10.99.0.0/24", 0) != cidrhost(vm.ip, 0)
    ])
    error_message = "A VM sits in the WireGuard net 10.99.0.0/24 — pick another tunnel net"
  }
}

run "gateway_snippet_has_tunnel_and_firewall" {
  command = plan

  assert {
    condition     = module.gateway.bootstrap_has_secret
    error_message = "gateway's snippet carries a private key and must use salt_bootstrap_secret (ignore_changes)"
  }

  assert {
    condition = alltrue([for s in [
      "Address = 10.99.0.2/24",
      "PrivateKey = mocked-gateway-private-key",
      "PublicKey = mocked-cloud-edge-public-key",
      "Endpoint = 92.6.177.252:51820",
      "PersistentKeepalive = 25",
      "net.ipv4.ip_forward = 1",
      "type filter hook forward priority filter; policy drop;",
      "systemctl enable --now wg-quick@wg0",
    ] : strcontains(module.gateway.bootstrap_rendered, s)])
    error_message = "gateway's cloud-init is missing part of the WireGuard/forwarding/nftables setup"
  }
}

run "ci_never_reads_wireguard_keys" {
  command = plan

  variables {
    wireguard_from_vault = false
  }

  assert {
    condition     = length(data.vault_kv_secret_v2.wg_gateway) == 0 && length(data.vault_kv_secret_v2.wg_cloud_edge) == 0
    error_message = "With wireguard_from_vault = false no WireGuard secret may be read"
  }
}

# firewall.tf: jede von Tofu verwaltete VM hat Regeln + scharfe Optionen —
# eine neue VM ohne Eintrag in fw_vms/fw_rules faellt hier auf.
run "every_vm_has_firewall_rules" {
  command = plan

  assert {
    condition     = alltrue([for name in keys(output.vm_inventory) : contains(keys(proxmox_virtual_environment_firewall_rules.vm), name)])
    error_message = "A VM in vm_inventory has no entry in firewall.tf (fw_vms + fw_rules)"
  }

  assert {
    condition     = alltrue([for o in proxmox_virtual_environment_firewall_options.vm : o.enabled && o.input_policy == "DROP"])
    error_message = "Every VM firewall must be enabled with input_policy DROP"
  }
}

# Aussperr-Schutz: die Cluster-Firewall darf die PVE-Hosts nicht filtern.
run "cluster_firewall_keeps_hosts_open" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_cluster_firewall.this.input_policy == "ACCEPT"
    error_message = "Cluster firewall input_policy must stay ACCEPT (else the PVE hosts lock out)"
  }
}
