MODULES := modules/vm-instance modules/vm-template

.PHONY: fmt fmt-check validate test test-modules lint ci

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

# fmt-check + validate + all tests, no real Proxmox/OpenBao access required
ci: fmt-check validate test test-modules
