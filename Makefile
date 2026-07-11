TF       := tofu
TFVARS   := terraform.tfvars
PLAN     := tfplan

.PHONY: init validate fmt plan apply destroy refresh output console clean apps system data

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

# Target a single resource: make target T=module.gitea
target:
	$(TF) plan -var-file=$(TFVARS) -target=$(T) -out=$(PLAN)

# Apply with an alternate var-file: make plan-with V=main-rustpad.tfvars
plan-with:
	$(TF) plan -var-file=$(V) -out=$(PLAN)

apply-with:
	$(TF) apply -var-file=$(V) -auto-approve

# Drive an independent sub-stack (own state). Defaults to apply-auto; pick a
# sub-target with CMD=, e.g. make system CMD=plan. Recommended apply order is
# data -> apps -> system, since system HTTPRoutes land in the app namespaces.
apps:
	$(MAKE) -C apps $(if $(CMD),$(CMD),apply-auto)

system:
	$(MAKE) -C system $(if $(CMD),$(CMD),apply-auto)

data:
	$(MAKE) -C data $(if $(CMD),$(CMD),apply-auto)
