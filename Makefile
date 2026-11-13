# aviary-deploy: three independent OpenTofu stacks, each with its own state.
# Apply order is data -> apps -> system (the system stack's HTTPRoutes land in
# the app namespaces and the apps' ExternalName aliases point at the gateway);
# destroy runs in reverse. Per-stack targets live in stack.mk.
#
#   make plan           # plan every stack
#   make apply          # apply the saved plans, in order
#   make apply-auto     # plan + apply in one go, in order
#   make system CMD=plan   # one stack, any stack.mk target (default apply-auto)

STACKS  := data apps system
RSTACKS := system apps data

.PHONY: all init validate fmt plan apply apply-auto destroy refresh output clean $(STACKS)

all: apply-auto

init validate plan apply apply-auto refresh output clean:
	@for s in $(STACKS); do $(MAKE) --no-print-directory -C $$s $@ || exit 1; done

destroy:
	@for s in $(RSTACKS); do $(MAKE) --no-print-directory -C $$s $@ || exit 1; done

# (tofu fmt -recursive trips over the symlinked files; list them instead)
fmt:
	tofu fmt *.tf $(foreach s,$(STACKS) disabled,$(wildcard $(s)/*.tf))

# Drive one stack: make apps CMD=plan (default: apply-auto)
$(STACKS):
	$(MAKE) --no-print-directory -C $@ $(if $(CMD),$(CMD),apply-auto)
