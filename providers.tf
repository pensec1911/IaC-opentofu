terraform {
  required_version = ">= 1.8.0" # mock_provider/override_data in tests need >= 1.8
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    netbox = {
      source  = "e-breuninger/netbox"
      version = "~> 5.8.0"
    }
  }

  # State in Postgres auf forgejo (formulas/tofu-state in IaC-salt), damit
  # die Forgejo-Actions-Jobs (plan in PRs, Drift-Check) denselben State sehen.
  # conn_str kommt aus backend.hcl (lokal, gitignored) bzw. PG_CONN_STR (CI) —
  # siehe README "State".
  backend "pg" {
    schema_name = "homelab"
  }

  # Client-seitig verschluesselt: in der DB (und deren Backups) liegt nur
  # Chiffretext. Passphrase aus var.state_passphrase (OpenBao
  # tofu-state/encryption). enforced: nie Klartext schreiben (README "State").
  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }
    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}

provider "vault" {
  address          = var.vault_address
  skip_tls_verify  = true
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }

  }
}

locals {
  # Proxmox-Nodes und ihre Management-IPs. Einzige Stelle: auch netbox.tf liest
  # sie (Nodes als Devices).
  pve_nodes = {
    pve01 = "192.168.178.11"
    pve02 = "192.168.178.12"
    pve03 = "192.168.178.13"
  }

  # fileexists-Guard, damit `tofu test`/CI ohne den Key durchlaeuft (dort ist
  # der Provider gemockt und SSH wird nie benutzt).
  proxmox_ssh_private_key = fileexists(pathexpand(var.proxmox_ssh_private_key_path)) ? file(pathexpand(var.proxmox_ssh_private_key_path)) : null
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
  insecure  = var.proxmox_insecure
  # Der Provider braucht SSH als root fuer Dinge, die die PVE-API nicht kann —
  # v.a. Snippet-Uploads (content_type "snippets"). Key direkt statt ssh-agent:
  # ein nicht geladener Agent hat hier schon zweimal mitten im Apply gestoppt.
  # ~/.ssh/config wird vom Provider bewusst ignoriert.
  ssh {
    agent       = false
    username    = "root"
    private_key = local.proxmox_ssh_private_key

    dynamic "node" {
      for_each = local.pve_nodes
      content {
        name    = node.key
        address = node.value
      }
    }
  }
}

# NetBox ist reines Inventar: OpenTofu schreibt, niemand liest daraus (netbox.tf).
provider "netbox" {
  server_url = var.netbox_url
  api_token  = data.vault_kv_secret_v2.netbox.data["api_token"]
}
