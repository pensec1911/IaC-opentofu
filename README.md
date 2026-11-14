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

## State

Der State liegt in Postgres auf forgejo (`192.168.178.29:5432`, DB `tofu`,
Schema `homelab`; `formulas/tofu-state` in IaC-salt, nightly per pg_dump
gesichert) — `backend "pg"` in `providers.tf`. Locking macht der Backend selbst
(Advisory Locks). Der State ist **client-seitig verschluesselt** (`encryption`,
pbkdf2 + AES-GCM): in der DB und im Backup liegt nur Chiffretext.

Lokal (beide Dateien gitignored):

- `backend.hcl`: `conn_str = "postgres://tofu:<pw>@192.168.178.29:5432/tofu?sslmode=disable"`
  (Passwort: OpenBao `tofu-state/postgres`, Key `password`)
- `terraform.tfvars`: `state_passphrase = "<…>"` (OpenBao `tofu-state/encryption`,
  Key `passphrase`). **Ohne die Passphrase ist der State verloren** — sie liegt
  nur in OpenBao (und dessen Backup).

Init: `make init` (= `tofu init -backend-config=backend.hcl`).

Migriert vom lokalen `terraform.tfstate` am 2026-11-14 (`tofu init -migrate-state`
mit einem voruebergehenden `unencrypted`-Fallback, danach entfernt). Auf einer neuen
Maschine: `backend.hcl` + `state_passphrase` anlegen, `make init`.

**Bekannte Dauer-Diff:** die drei `debian13_template`-VMs zeigen
`ipv4_addresses`/`ipv6_addresses`/`network_interface_names` `[] -> (known after apply)`
(berechnete Felder, Templates laufen nie) — schon vor der Migration so. Der
Drift-Check meldet sie, bis sie weg ist.

## CI: Plan in PRs + Drift-Check

Forgejo Actions (`.forgejo/workflows/`, Runner `docker` auf forgejo):

- `plan.yml` — jeder PR: `tofu plan`, die Ressourcen-Zeilen (`# x will be
  created` …) und die `Plan:`-Zeile als PR-Kommentar (bei jedem Push
  aktualisiert). Volle Diff nur im Job-Log.
- `drift.yml` — taeglich 06:30 UTC auf main: nicht leerer Plan → Issue
  "Tofu drift: plan not empty" (aktualisiert, schliesst sich bei leerem Plan).

Beide nur `plan`, mit `-lock=false` (blockiert nie ein lokales Apply). `apply`
bleibt lokal. Die Jobs bekommen **nur lesende Credentials**:

1. Proxmox: `pveum user add tofu-plan@pve`, `pveum acl modify / -user tofu-plan@pve -role PVEAuditor`,
   `pveum user token add tofu-plan@pve ci --privsep 0` →
   `bao kv put -mount=homelab proxmox/plan api_token=tofu-plan@pve!ci=<uuid>` (das ganze
   `USER@REALM!TOKENID=UUID`, nicht nur die UUID).
   PVEAuditor allein reicht fuer `plan` (mit Refresh) nicht:
   - Disk-Infos **jeder** VM brauchen `VM.Config.Disk` →
     `pveum role add TofuPlanExtra -privs VM.Config.Disk`,
     `pveum acl modify / --users tofu-plan@pve --roles TofuPlanExtra`.
   - Snippets zeigt PVE 9 nur mit `Datastore.Allocate` (`check_volume_access` in
     `PVE/Storage.pm`; `AllocateSpace` reicht nicht) → nur auf `local`:
     `pveum role add TofuPlanLocal -privs Datastore.Allocate`,
     `pveum acl modify /storage/local --users tofu-plan@pve --roles PVEAuditor,TofuPlanLocal`.
     PVEAuditor dort nochmal, weil ein spezifischer ACL-Eintrag fuer den User den geerbten
     von `/` ersetzt.
   Restrisiko (bewusst akzeptiert, 2026-11-14): wer an die CI-Secrets kommt, kann Disks aller
   VMs aendern und auf `local` alles loeschen/ersetzen (ISOs, CT-Templates, Snippets,
   Backups) — keine VMs anlegen/loeschen, `local-lvm` nur ueber VM.Config.Disk.
2. NetBox: zweiter API-Token fuer `opentofu`, **Write aus** →
   `bao kv put -mount=homelab netbox/tofu-plan api_token=<token>`.
3. OpenBao: Policy `tofu-plan` mit nur `read` auf `homelab/data/proxmox/plan` und
   `homelab/data/netbox/tofu-plan`, AppRole `tofu-plan` mit dieser Policy.
4. Forgejo → IaC-opentofu → Settings → Actions:
   - Secrets: `PG_CONN_STR` (wie `conn_str` oben), `STATE_PASSPHRASE`,
     `VAULT_ROLE_ID` / `VAULT_SECRET_ID` (AppRole `tofu-plan`)
   - Variables: `PROXMOX_ENDPOINT`, `TARGET_NODE`, `SSH_PUBLIC_KEY` — exakt wie
     in der lokalen `terraform.tfvars`, sonst zeigt der Plan Cloud-Init-Diffs.

Die Workflows waehlen die Lese-Tokens ueber `TF_VAR_proxmox_vault_secret` /
`TF_VAR_netbox_vault_secret`. Kein SSH-Key im Job: `plan` braucht SSH nicht
(nur Snippet-Uploads beim Apply).

## Testing

Three layers, all runnable offline (no real Proxmox or OpenBao access needed) via `mock_provider`:

| Layer | Command | What it catches |
|---|---|---|
| Format & syntax | `make fmt-check`, `make validate` | drift, typos, type errors |
| Module unit tests | `make test-modules` | regressions in `modules/vm-instance` and `modules/vm-template` behavior (optional `disk_size`/`vlan_id`, checksum handling, template validation, etc.) — see `<module>/tests/*.tftest.hcl` |
| Fleet invariants | `make test` | whole-repo checks in `tests/fleet.tftest.hcl`: no two VMs share an `ip_address`, no Proxmox node's combined `memory_mb` exceeds its 16GB budget, no duplicate IP/name among the NetBox entries (incl. unmanaged VMs and devices) |

Run everything with `make ci`. The same steps run in GitHub Actions on the GitHub mirror (`.github/workflows/test.yml`); Forgejo runs `.forgejo/workflows/` instead (CI section above).

Requires OpenTofu >= 1.8 (for `mock_provider`/`override_data` in tests).

What this does **not** cover: an actual `tofu apply` against real Proxmox/OpenBao. That's intentionally left manual — there's no disposable Proxmox environment to safely automate against yet.
