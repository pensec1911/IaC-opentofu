# IaC-opentofu

## Voraussetzungen fuer `tofu apply`

Neben dem Proxmox-API-Token (kommt aus OpenBao, siehe `vault.tf`) braucht der
Provider **SSH-Zugriff als root auf jeden PVE-Node**. Das ist keine Option:
Cloud-Init-Snippets (`content_type = "snippets"`) kann die PVE-API nicht
hochladen, der Provider faellt dort auf SFTP zurueck.

- Key: `var.proxmox_ssh_private_key_path`, Default `~/.ssh/homelab`
- Der zugehoerige Public Key muss in `/root/.ssh/authorized_keys` auf pve01,
  pve02 und pve03 liegen
- Pruefen: `ssh -i ~/.ssh/homelab root@192.168.178.11 hostname`

Der Provider liest den Key direkt, bewusst **nicht** ueber `ssh-agent` — ein
nicht geladener Agent bricht den Apply erst mitten im Lauf ab. `~/.ssh/config`
wird vom Provider grundsaetzlich ignoriert.

## Aufbau

- **Ein Template pro Node** (`main.tf`, `local.template_nodes`). Es gibt keinen
  Shared Storage, und ein Cross-Node-Clone muesste darum die komplette Disk auf
  den Ziel-Node migrieren — das laeuft in den Provider-Timeout und hinterlaesst
  halb fertige VMs. Jede VM klont deshalb vom Template auf ihrem eigenen Node.
- **Template-Disk per `import_from`** (`modules/vm-template`), also serverseitig
  per API. Das alternative `file_id` wuerde den Provider per SSH `qm importdisk`
  aufrufen lassen.
- **Salt kommt nicht aus Debian.** In trixie sind die Salt-Pakete entfernt, der
  Bootstrap richtet darum das offizielle Repo bei Broadcom ein und pinnt auf die
  LTS-Linie (`var.salt_version_pin`, Default `3008.*`).
- **Aenderungen am Salt-Bootstrap bauen keine VM neu.** vendor-data wird nur beim
  ersten Boot gelesen, darum referenziert die VM das Snippet ueber eine feste
  File-ID. Rebuild bei Bedarf bewusst per `tofu apply -replace=module.<vm>.module.vm.proxmox_virtual_environment_vm.this`.

## Testing

Three layers, all runnable offline (no real Proxmox or OpenBao access needed) via `mock_provider`:

| Layer | Command | What it catches |
|---|---|---|
| Format & syntax | `make fmt-check`, `make validate` | drift, typos, type errors |
| Module unit tests | `make test-modules` | regressions in `modules/vm-instance` and `modules/vm-template` behavior (optional `disk_size`/`vlan_id`, checksum handling, template validation, etc.) — see `<module>/tests/*.tftest.hcl` |
| Fleet invariants | `make test` | whole-repo checks in `tests/fleet.tftest.hcl`: no two VMs share an `ip_address`, no Proxmox node's combined `memory_mb` exceeds its 16GB budget |

Run everything with `make ci`. The same steps run in GitHub Actions on every push/PR (`.github/workflows/test.yml`).

Requires OpenTofu >= 1.8 (for `mock_provider`/`override_data` in tests).

What this does **not** cover: an actual `tofu apply` against real Proxmox/OpenBao. That's intentionally left manual — there's no disposable Proxmox environment to safely automate against yet.
