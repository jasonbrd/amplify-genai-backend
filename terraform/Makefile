# Local build/validation loop for the Terraform migration.
# These targets are fully offline — no AWS credentials and no AWS API calls.
# (`terraform plan`/`apply` are intentionally NOT here; they require AWS access
# because the config reads live data sources and changes infrastructure.)

.PHONY: all check fmt fmt-check validate lint init-local clean

all: check

# Format, validate, and lint — the full local gate.
check: fmt-check validate lint

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive

# Backendless init so validate/lint can resolve modules without remote state.
init-local:
	terraform init -backend=false -input=false >/dev/null

validate: init-local
	terraform validate

lint:
	tflint --init >/dev/null
	tflint --recursive

clean:
	rm -rf .terraform .terraform.lock.hcl build
	find . -type d -name '.terraform' -prune -exec rm -rf {} +
