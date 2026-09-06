# IaC-opentofu

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
