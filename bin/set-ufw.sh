#!/usr/bin/env bash
# Rebuild the ufw rules on the NAT / mesh hub box (timesink) from scratch: delete every user rule, then add
# back only what the box needs as mesh hub, hypervisor and aviary NAT host.
#
#   bin/set-ufw.sh -n    # print what would be done, change nothing
#   sudo bin/set-ufw.sh  # do it (backs /etc/ufw up first)
#
# It deletes rules one by one instead of `ufw reset`, so before.rules and
# after.rules (which xdebbied touches) are left alone and xdebbied does not
# need a restart afterwards. Established connections (your ssh) survive.
# Forwarding targets come from /etc/default/aviary-nat, the file
# bin/set-nat.sh saves. Run set-nat.sh again afterwards.
set -euo pipefail
export PATH=$PATH:/usr/sbin:/sbin

LAN=${LAN:-192.168.1.0/24}
WG_NET=${WG_NET:-10.22.0.0/16}      # wireguard underlay
VM_NET=${VM_NET:-10.23.0.0/16}      # mesh bridge / VMs / LB pool
WG_DEV=${WG_DEV:-wg-flock}
BR_DEV=${BR_DEV:-virbr-xdebbie}
SSH_FROM=${SSH_FROM:-any}           # e.g. SSH_FROM="$LAN" to close ssh to the internet
SAVED=/etc/default/aviary-nat
saved() { { sed -n "s/^$1=//p" "$SAVED" 2>/dev/null || true; } | head -1; }

GW=${NAT_GATEWAY_IP:-$(saved NAT_GATEWAY_IP)}
PORTS=${PORTS:-$(saved PORTS)};                PORTS=${PORTS:-80 443}
SMTP_IP=${SMTP_IP:-$(saved SMTP_IP)}
SMTP_PORTS=${SMTP_PORTS:-$(saved SMTP_PORTS)}; SMTP_PORTS=${SMTP_PORTS:-25 465 587}
JVB_IP=${JVB_IP:-$(saved JVB_IP)}
JVB_PORTS=${JVB_PORTS:-$(saved JVB_PORTS)};    JVB_PORTS=${JVB_PORTS:-10000}
DNS_PORTS=${DNS_PORTS:-$(saved DNS_PORTS)};    DNS_PORTS=${DNS_PORTS:-53}
[ "$DNS_PORTS" != none ] || DNS_PORTS=""
csv() { echo "$*" | xargs | sed 's/ /,/g'; }

MODE=apply
case "${1:-}" in "") ;; -n) MODE=print ;; *) echo "usage: $0 [-n]" >&2; exit 1 ;; esac
run() { if [ "$MODE" = print ]; then echo "+ $*"; else "$@" >/dev/null; echo "  $*"; fi; }

if [ "$MODE" = apply ]; then
    [ "$(id -u)" = 0 ] || { echo "run as root (or -n to only print)" >&2; exit 1; }
    BAK=/root/ufw-backup-$(date +%Y%m%d-%H%M%S)
    cp -a /etc/ufw "$BAK"; ufw status numbered > "$BAK/status.txt" 2>&1 || true
    echo "backup: $BAK"
    # --- flush: delete rule 1 until there are none ---------------------------
    n=0
    while ufw status numbered | grep -q '^\[ *1\]'; do
        ufw --force delete 1 >/dev/null; n=$((n + 1))
        [ $n -lt 500 ] || { echo "gave up deleting after 500 rules" >&2; exit 1; }
    done
    echo "deleted $n old rules"
else
    echo "+ (back up /etc/ufw, then 'ufw --force delete 1' until no rules are left)"
fi

run ufw default deny incoming
run ufw default allow outgoing
run ufw default deny routed

# --- to this box -------------------------------------------------------------
if [ "$SSH_FROM" = any ]; then run ufw allow 22/tcp comment ssh
else run ufw allow proto tcp from "$SSH_FROM" to any port 22 comment ssh; fi
run ufw allow 51820/udp comment 'mesh wireguard'
for net in $LAN $WG_NET $VM_NET; do
    run ufw allow proto tcp from "$net" to any port 7443 comment 'xdebbie api'
    run ufw allow proto udp from "$net" to any port 7442 comment 'xdebbie discovery'
    run ufw allow from "$net" to any port 53 comment 'dns (coredns)'
done
for dev in $WG_DEV $BR_DEV; do
    run ufw allow in on "$dev" proto udp to any port 6081 comment 'xdebbie geneve'
    run ufw allow in on "$dev" proto tcp to any port 16514 comment 'libvirt tls'
done
run ufw allow in on "$WG_DEV" proto tcp from "$WG_NET" to any port 23000:23999 comment 'abe nvme/tcp'
run ufw allow in on "$WG_DEV" proto tcp from "$WG_NET" to any port 443 comment 'abe api'
run ufw allow in on "$BR_DEV" proto tcp from "$VM_NET" to any port 3142 comment 'apt-cacher-ng'
run ufw allow in on "$BR_DEV" proto udp to any port 67 comment 'vm dhcp'

# --- through this box --------------------------------------------------------
run ufw route allow in on "$BR_DEV" comment 'vms out (internet, mesh, each other)'
run ufw route allow in on "$WG_DEV" out on "$BR_DEV" comment 'mesh to vms'
if [ -n "$GW" ]; then
    run ufw route allow out on "$BR_DEV" to "$GW" port "$(csv $PORTS)" proto tcp comment 'aviary-nat web'
    if [ -n "$DNS_PORTS" ]; then
        run ufw route allow out on "$BR_DEV" to "$GW" port "$(csv $DNS_PORTS)" proto tcp comment 'aviary-nat dns'
        run ufw route allow out on "$BR_DEV" to "$GW" port "$(csv $DNS_PORTS)" proto udp comment 'aviary-nat dns'
    fi
else
    echo "note: no NAT_GATEWAY_IP (none in $SAVED): no web forwarding rules added" >&2
fi
[ -z "$SMTP_IP" ] || run ufw route allow out on "$BR_DEV" to "$SMTP_IP" port "$(csv $SMTP_PORTS)" proto tcp comment 'aviary-nat smtp'
[ -z "$JVB_IP" ]  || run ufw route allow out on "$BR_DEV" to "$JVB_IP" port "$(csv $JVB_PORTS)" proto udp comment 'aviary-nat jitsi media'

run ufw --force enable
[ "$MODE" = print ] || { echo; ufw status verbose; echo; echo "now re-run: sudo bin/set-nat.sh"; }
