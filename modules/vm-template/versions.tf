terraform {
  required_version = ">= 1.8.0" # mock_provider in module tests needs >= 1.8

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}
