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

## OCI (cloud-edge)

Eigenes Root-Modul `oci/` fuer die eine Oracle-Cloud-VM `cloud-edge` (VM.Standard.A1.Flex,
arm64, 1 OCPU / 6 GB, Always Free). Dort laeuft nur Headscale mit eingebautem DERP-Relay
(IaC-salt `formulas/headscale`) und der WireGuard-Server `10.99.0.1` fuer den
Verwaltungstunnel zu `gateway` (Salt, Backup, Monitoring). Kein Reverse-Proxy, keine Apps.

- **Eigener State**: gleiche Postgres-DB, Schema `oci`, gleiche Verschluesselung
  (`state_passphrase`). Ein Proxmox-Apply fasst Oracle nie an und umgekehrt.
  Init: `make oci-init`, danach `tofu -chdir=oci plan|apply` (gleiche `terraform.tfvars`-Werte
  `state_passphrase`, `vault_role_id`, `vault_secret_id`, `ssh_public_key` — als
  `oci/terraform.tfvars` oder `TF_VAR_*`).
- **Offen** sind nur 443/tcp (Headscale + DERP, Zertifikat per TLS-ALPN-01), 3478/udp (STUN),
  51820/udp (WireGuard). Die Default-Security-List (Oracle oeffnet dort 22/tcp fuer alle) wird
  auf Path-MTU-ICMP reduziert. Kein oeffentliches SSH: SSH geht nur ueber `wg0` aus dem LAN,
  Notzugang ist die Serial Console (Login mit dem Salt-Login-Account `cloud-edge`, sobald der
  erste Highstate durch ist).
- **Reservierte Public IP** (`prevent_destroy`): bleibt ueber Stop/Start und Rebuild. Darauf
  zeigt `hs.ilpaa.xyz` (A-Record **manuell** bei Porkbun — die Porkbun-Provider fuer Tofu sind
  archiviert bzw. Ein-Personen-Projekte, fuer einen Record, der sich nie aendert, lohnt das nicht).
- **cloud-init** kommt aus `modules/cloud-init` (dasselbe Bootstrap wie die Proxmox-VMs plus
  WireGuard, nftables und feste Minion-ID — ohne sie waere der FQDN `cloud-edge.<subnet>.oraclevcn.com`
  die ID). Wie bei Proxmox wirkt es nur beim ersten Boot: `user_data` steht in
  `ignore_changes`, Rebuild bewusst per `tofu -chdir=oci apply -replace=oci_core_instance.cloud_edge`.
- **Restrisiko**: der private WireGuard-Key steht in den Instance-Metadaten (nur IMDSv2, aber fuer
  jeden lokalen Prozess lesbar) und im verschluesselten State.

### Einmalig, manuell

1. Oracle-Account auf **Pay-As-You-Go** (sonst holt Oracle idle A1-Instanzen zurueck) + Budget-Alarm.
2. Compartment `homelab`; Gruppe `tofu-admins` mit User `tofu`:
   `Allow group tofu-admins to manage all-resources in compartment homelab` und
   `Allow group tofu-admins to read objectstorage-namespaces in tenancy`.
   Gruppe `tofu-plan` mit User `tofu-plan` (fuer CI): `Allow group tofu-plan to read all-resources in tenancy`.
3. Je User einen API-Key (`openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out k.pem`,
   `openssl rsa -pubout -in k.pem`, Public Key in der Konsole hochladen), dann auf dem OpenBao-Host:
   `bao kv put -mount=homelab oci/api tenancy_ocid=… user_ocid=… fingerprint=… region=eu-frankfurt-1 compartment_ocid=… private_key=@k.pem`
   (fuer `tofu-plan` dasselbe nach `oci/plan`), danach `shred -u k.pem`.
4. WireGuard-Keys (beide Endpunkte, ohne Datei):
   `k=$(wg genkey); bao kv put -mount=homelab wireguard/cloud-edge private_key="$k" public_key="$(echo "$k" | wg pubkey)"; unset k`
   und dasselbe fuer `wireguard/gateway`.
5. OpenBao-Policies: `tofu-proxmox` (AppRole `tofu`) `read` auf `homelab/data/oci/api` und
   `homelab/data/wireguard/*`; `tofu-plan` nur `read` auf `homelab/data/oci/plan` — **keine**
   WireGuard-Keys (CI rendert Platzhalter, `TF_VAR_wireguard_from_vault=false`).

### Erster Apply (zweistufig, wegen des Images)

Der OCI-Provider prueft eine lokale Upload-Datei bei jedem Plan — CI haette sie nie. Darum laedt
Tofu das qcow2 nicht selbst hoch:

1. `make oci-image` (laedt `debian-13-genericcloud-arm64.qcow2`, prueft SHA512SUMS).
2. `tofu -chdir=oci apply -target=oci_objectstorage_bucket.images[0]`.
3. Upload nach Bucket `homelab-images`, Objektname `debian-13-genericcloud-arm64.qcow2`
   (Konsole → Object Storage, oder `oci os object put`).
4. `tofu -chdir=oci apply` — Import (bis ~20 min), UEFI + A1-Shape, Instanz, reservierte IP.
   „Out of host capacity" → `availability_domain_index` 1 oder 2.
5. `hs.ilpaa.xyz` A → Output `public_ip` bei Porkbun anlegen (TTL 600).
6. Pruefen ueber die Serial Console: `cloud-init status` = done, `wg show` zeigt den Listener.
   Der Salt-Key kommt erst, wenn `gateway` den Tunnel aufbaut; dann auf dem Master
   `salt-key -a cloud-edge` (IaC-salt formulas/salt-master README "Accepting minion keys").

Danach darf das Objekt aus dem Bucket geloescht werden (`image_source_details` ist ignoriert).
**Fallback**, falls Import oder cloud-init auf dem Debian-Image nicht funktionieren:
`use_platform_image = true` nimmt Oracles Ubuntu 24.04 aarch64 (Login-User `ubuntu`).

### CI

`plan.yml` und `drift.yml` haben einen zweiten Job `plan-oci` (Working-Directory `oci/`, eigener
PR-Kommentar und eigenes Drift-Issue „Tofu drift (oci): …"). Er nutzt den nur lesenden OCI-User
`tofu-plan` und liest keine WireGuard-Keys. Der Drift-Check meldet z. B. in der Konsole
geoeffnete NSG-Ports oder eine gestoppte/zurueckgeholte Instanz.

## gateway + edge (pve01)

- **gateway** (.31, 1 CPU / 1 GB): WireGuard-Client zu cloud-edge (`wg0` 10.99.0.2, Endpoint =
  reservierte OCI-IP, fest in `vms/gateway/main.tf`), IPv4-Forwarding und nftables. Die
  `forward`-Chain ist die einzige Stelle, die festlegt, was cloud-edge im LAN erreichen darf
  (Salt 4505/4506, NFS, Loki, Healthchecks, PatchMon) und umgekehrt (Prometheus-Scrapes, SSH).
  Spaeter Tailscale-Subnet-Router (IaC-salt). Voraussetzung: FRITZ!Box-Route
  `10.99.0.0/24 → 192.168.178.31`.
- Das Snippet von gateway enthaelt den WireGuard-Private-Key (OpenBao `wireguard/gateway`) und
  liegt deshalb in `salt_bootstrap_secret` mit `ignore_changes`: CI liest keine WireGuard-Keys
  (`TF_VAR_wireguard_from_vault=false`, Platzhalter) und meldet so keinen Dauer-Drift. Folge:
  Aenderungen an Tunnel/Firewall wirken nur per Rebuild —
  `tofu apply -replace='module.gateway.module.vm.proxmox_virtual_environment_file.salt_bootstrap_secret[0]' -replace='module.gateway.module.vm.proxmox_virtual_environment_vm.this'`
  (zustandsarm; Tailscale braucht danach einen neuen Pre-Auth-Key).
- **edge** (.30, 2 CPU / 4 GB): normale LAN-VM fuer Caddy + Authentik (IaC-salt).
- Neue Minions: Keys auf dem Master von Hand akzeptieren (`salt-key -a gateway`, `-a edge`,
  `-a cloud-edge` sobald der Tunnel steht).

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

Three layers, all runnable offline (no real Proxmox, OCI or OpenBao access needed) via `mock_provider`:

| Layer | Command | What it catches |
|---|---|---|
| Format & syntax | `make fmt-check`, `make validate` | drift, typos, type errors |
| Module unit tests | `make test-modules` | regressions in `modules/vm-instance` and `modules/vm-template` behavior (optional `disk_size`/`vlan_id`, checksum handling, template validation, etc.) — see `<module>/tests/*.tftest.hcl` |
| cloud-init | `make test-modules` | `modules/cloud-init`: Bootstrap ohne Netz-Optionen byte-gleich zum bisherigen (kein Snippet-Diff), WireGuard/nftables/Minion-ID korrekt gerendert |
| OCI | `make test-oci` | `oci/`: nur 443/3478/51820 offen, Default-Security-List ohne 22, Always-Free-Groesse, reservierte IP, IMDSv2, cloud-init mit Tunnel, CI liest keine WireGuard-Keys |
| Fleet invariants | `make test` | whole-repo checks in `tests/fleet.tftest.hcl`: no two VMs share an `ip_address`, no Proxmox node's combined `memory_mb` exceeds its RAM (`node_memory_mb` in `outputs.tf`: pve01 32 GB, pve02/pve03 16 GB), no duplicate IP/name among the NetBox entries (incl. unmanaged VMs and devices) |

Run everything with `make ci`. The same steps run in GitHub Actions on the GitHub mirror (`.github/workflows/test.yml`); Forgejo runs `.forgejo/workflows/` instead (CI section above).

Requires OpenTofu >= 1.8 (for `mock_provider`/`override_data` in tests).

What this does **not** cover: an actual `tofu apply` against real Proxmox/OpenBao. That's intentionally left manual — there's no disposable Proxmox environment to safely automate against yet.
