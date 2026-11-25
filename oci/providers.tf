# Eigenes Root-Modul fuer Oracle Cloud (cloud-edge: Headscale + DERP +
# WireGuard-Server), mit eigenem State: gleiche Postgres-DB wie das
# Proxmox-Root-Modul, eigenes Schema `oci`, gleiche Verschluesselung (README
# "OCI"). Ein Proxmox-Apply fasst Oracle so nie an und umgekehrt.
terraform {
  required_version = ">= 1.8.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.15"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }

  # conn_str aus ../backend.hcl bzw. PG_CONN_STR (CI), wie im Root-Modul.
  backend "pg" {
    schema_name = "oci"
  }

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

# API-Key-Auth aus OpenBao (README "OCI"): lokal der User `tofu`, in CI der
# nur lesende `tofu-plan` (var.oci_vault_secret).
provider "oci" {
  tenancy_ocid = local.oci.tenancy_ocid
  user_ocid    = local.oci.user_ocid
  fingerprint  = local.oci.fingerprint
  private_key  = local.oci.private_key
  region       = local.oci.region
}
