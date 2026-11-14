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

## NetBox

`netbox.tf` schreibt bei jedem Apply Proxmox-Nodes, NAS, FRITZ!Box, alle VMs und ihre IPs nach
NetBox (`formulas/netbox` in IaC-salt, http://192.168.178.29:8000). Richtung ist fest:
**Tofu schreibt, NetBox liest nur** — nichts (weder Tofu noch Salt) liest aus NetBox zurueck.
Alles mit Tag `opentofu` nicht in der UI aendern, der naechste Apply setzt es zurueck. Ports
und Services stehen weiter in IaC-salt (`.claude/docs/inventory.md`).

- VMs aus `vms.tf` kommen automatisch (ueber `local.vm_inventory`). Laufende VMs ohne
  Tofu-Modul (openbao) stehen in `local.netbox_unmanaged_vms` — beim
  Ein-/Auskommentieren eines Moduls dort nachziehen (`make test` prueft auf Doppelte).
- Provider `e-breuninger/netbox` 5.8.x: offiziell bis NetBox 4.6 getestet, beim Init kommt
  eine (nicht blockierende) Versionswarnung. 6.x ist ein Rewrite mit Umbenennungen
  (`netbox_interface` → `netbox_virtual_machine_interface`, Primary-IPs) — Upgrade bewusst,
  mit Migration Guide.
- **NetBox down = `tofu plan/apply` scheitert** (Refresh). Forgejo selbst neu bauen:
  `tofu apply -target=module.forgejo`, danach normal.

Einmalig, manuell (vor dem ersten Apply mit `netbox.tf`):

1. NetBox-UI → Admin → Users: User `opentofu` anlegen (kein Superuser). Das
   Permissions-Feld dort listet nur bestehende Permissions — also danach:
   Admin → Permissions → Add (`/users/permissions/add/`): Aktionen view/add/change/delete,
   Object types dcim (site, manufacturer, device type, device role, device, interface),
   ipam (prefix, ip address), virtualization (cluster type, cluster, virtual machine,
   interface), extras (tag); Assignment → Users: `opentofu`; keine Constraints.
2. Admin → API Tokens → Add: User `opentofu`, Write enabled (v2, `nbt_…`).
3. `bao kv put -mount=homelab netbox/tofu api_token=<token>` (auf dem OpenBao-Host).
4. Die Policy `tofu-proxmox` (AppRole `tofu`) um `read` auf `homelab/data/netbox/tofu` erweitern (bisher nur
   `homelab/data/proxmox`).
5. `tofu plan` — erwartet: nur `netbox_*`-Ressourcen neu, keine VM-Aenderung.

## Testing

Three layers, all runnable offline (no real Proxmox or OpenBao access needed) via `mock_provider`:

| Layer | Command | What it catches |
|---|---|---|
| Format & syntax | `make fmt-check`, `make validate` | drift, typos, type errors |
| Module unit tests | `make test-modules` | regressions in `modules/vm-instance` and `modules/vm-template` behavior (optional `disk_size`/`vlan_id`, checksum handling, template validation, etc.) — see `<module>/tests/*.tftest.hcl` |
| Fleet invariants | `make test` | whole-repo checks in `tests/fleet.tftest.hcl`: no two VMs share an `ip_address`, no Proxmox node's combined `memory_mb` exceeds its 16GB budget, no duplicate IP/name among the NetBox entries (incl. unmanaged VMs and devices) |

Run everything with `make ci`. The same steps run in GitHub Actions on every push/PR (`.github/workflows/test.yml`).

Requires OpenTofu >= 1.8 (for `mock_provider`/`override_data` in tests).

What this does **not** cover: an actual `tofu apply` against real Proxmox/OpenBao. That's intentionally left manual — there's no disposable Proxmox environment to safely automate against yet.
