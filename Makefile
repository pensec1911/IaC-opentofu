MODULES := modules/cloud-init modules/vm-instance modules/vm-template

.PHONY: init fmt fmt-check validate test test-modules test-oci oci-init oci-image lint ci

# Real backend (Postgres on forgejo); conn_str from the gitignored
# backend.hcl — README "State".
init:
	tofu init -backend-config=backend.hcl

fmt:
	tofu fmt -recursive

fmt-check:
	tofu fmt -check -recursive -diff

validate:
	tofu init -backend=false -input=false
	tofu validate

# Root-level tests (tests/*.tftest.hcl): whole-fleet invariants, e.g. no
# duplicate IPs, no node over its RAM budget. Providers are mocked, so this
# needs no real Proxmox/OpenBao access.
test:
	tofu test

# Each reusable module carries its own unit tests under <module>/tests/,
# which only run when tofu is invoked from inside that module's directory.
test-modules:
	@for m in $(MODULES); do \
		echo "==> $$m"; \
		(cd $$m && tofu init -backend=false -input=false -upgrade=false && tofu test) || exit 1; \
	done

# Second root module oci/ (cloud-edge on Oracle, own state schema `oci`) —
# README "OCI". Same backend.hcl as the root module.
oci-init:
	cd oci && tofu init -backend-config=../backend.hcl

# Offline: validate + mocked tests of oci/ (no OCI/OpenBao access).
test-oci:
	cd oci && tofu init -backend=false -input=false && tofu validate && tofu test

# Debian 13 genericcloud arm64 for the OCI custom image, checked against
# Debian's SHA512SUMS. Upload it once to the bucket homelab-images (console
# or OCI CLI), then apply — README "OCI".
OCI_IMAGE_URL := https://cloud.debian.org/images/cloud/trixie/latest
OCI_IMAGE := debian-13-genericcloud-arm64.qcow2
oci-image:
	cd oci && curl -fLO $(OCI_IMAGE_URL)/$(OCI_IMAGE) && curl -fsSL $(OCI_IMAGE_URL)/SHA512SUMS -o SHA512SUMS \
		&& grep ' $(OCI_IMAGE)$$' SHA512SUMS | sha512sum -c - && rm SHA512SUMS

# fmt-check + validate + all tests, no real Proxmox/OpenBao/OCI access required
ci: fmt-check validate test test-modules test-oci
