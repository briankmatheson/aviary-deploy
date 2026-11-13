# Shared Makefile for one stack (apps/, system/, data/): each has its own state
# and runs tofu in its own directory. providers.tf, versions.tf, variables.tf
# and terraform.tfvars are symlinks to the repo root. Driven from the root
# Makefile (make apply, make plan, ...) or directly: cd system && make plan.

TF       := tofu
TFVARS   := terraform.tfvars
PLAN     := tfplan

.PHONY: init validate fmt plan apply apply-auto destroy refresh output console clean target

init:
	$(TF) init -input=false

validate: init
	$(TF) validate

fmt:
	$(TF) fmt $(wildcard *.tf)

plan: init
	$(TF) plan -var-file=$(TFVARS) -out=$(PLAN)

apply:
	$(TF) apply $(PLAN)

apply-auto: init
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

# Plan a single resource: make target T=helm_release.grafana
target:
	$(TF) plan -var-file=$(TFVARS) -target=$(T) -out=$(PLAN)
