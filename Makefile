# aviary-deploy: two independent OpenTofu stacks, each with its own state.
# Apply order is apps -> system (the system stack's HTTPRoutes land in
# the app namespaces and the apps' ExternalName aliases point at the gateway);
# destroy runs in reverse. Per-stack targets live in stack.mk.
#
#   make plan           # plan every stack
#   make apply          # apply the saved plans, in order
#   make apply-auto     # plan + apply in one go, in order
#   make system CMD=plan   # one stack, any stack.mk target (default apply-auto)

STACKS  := apps system
RSTACKS := system apps

.PHONY: all set-dns apply-dns init validate fmt plan apply apply-auto destroy refresh output clean $(STACKS)

all: apply-dns

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

# Register the aviary DNS zone in the management cluster CoreDNS (wildcard
# -> Gateway LB IP, ssh.gitea -> Gitea ssh LB). Run after the stacks apply.
set-dns:
	@bin/set-dns.sh

# Apply every stack, then register DNS. This is what plain `make` runs.
apply-dns: apply-auto
	@$(MAKE) --no-print-directory set-dns

.PHONY: oauth
# Register the Gitea OAuth2 app for the landing page, write it into tfvars,
# then re-apply the apps stack to switch login on. Run after the stacks are up.
oauth:
	@bin/setup-oauth.sh
	@$(MAKE) --no-print-directory apps CMD=apply-auto
	@kc=$$(grep -m1 kubeconfig terraform.tfvars | sed 's/.*= *//; s/"//g'); KUBECONFIG=$$kc kubectl -n aviary rollout restart deploy/aviary-frontend && KUBECONFIG=$$kc kubectl -n aviary rollout status deploy/aviary-frontend --timeout=120s
