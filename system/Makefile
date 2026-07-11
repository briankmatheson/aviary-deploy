# system/ is an independent OpenTofu stack with its own state.
# Shared config (providers/versions/variables/locals/terraform.tfvars) is
# symlinked in from the repo root, so this Makefile mirrors the root one and
# runs tofu from within system/.

TF       := tofu
TFVARS   := terraform.tfvars
PLAN     := tfplan

.PHONY: init validate fmt plan apply apply-auto destroy refresh output console clean

init:
	$(TF) init

validate: init
	$(TF) validate

fmt:
	$(TF) fmt -recursive

plan:
	$(TF) plan -var-file=$(TFVARS) -out=$(PLAN)

apply:
	$(TF) apply $(PLAN)

apply-auto:
	$(TF) apply -var-file=$(TFVARS) -auto-approve

destroy:
	$(TF) destroy -var-file=$(TFVARS)

refresh:
	$(TF) refresh -var-file=$(TFVARS)

output:
	$(TF) output

console:
	$(TF) console -var-file=$(TFVARS)

clean:
	rm -f $(PLAN)

# Target a single resource: make target T=helm_release.grafana
target:
	$(TF) plan -var-file=$(TFVARS) -target=$(T) -out=$(PLAN)
