terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure # true nur solange kein gültiges TLS-Zertifikat auf dem PVE-Node liegt

  ssh {
    agent    = true
    username = "root" # nur nötig für Dinge wie qemu-guest-agent Wartezeiten / manche Disk-Operationen
  }
}
