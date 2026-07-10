TF       := tofu
TFVARS   := terraform.tfvars
PLAN     := tfplan

.PHONY: init validate fmt plan apply destroy refresh output console clean

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
