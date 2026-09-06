terraform {
  required_version = ">= 1.8.0" # mock_provider/override_data in tests need >= 1.8
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "vault" {
  address = var.vault_address

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
  insecure  = var.proxmox_insecure
  ssh {
    agent    = true
    username = "root"
  }
}
