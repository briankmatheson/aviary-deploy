#!/usr/bin/env bash
# NAT the outside world to the public Gateway (aviary-nat, nat_gateway_ip).
#
# Run this as root ON THE BOX THE ROUTER SENDS INBOUND TRAFFIC TO (its DMZ or
# port-forward host), which must also route to the cluster's LB network:
#
#   sudo bin/set-nat.sh        # install (safe to re-run: replaces its own rules)
#   bin/set-nat.sh -n          # print what would be done, change nothing
#   sudo bin/set-nat.sh -d     # remove everything it installed
#
# What it sets up, for tcp 80 and 443:
#   1. DNAT   traffic addressed to this box's LAN address(es) -> nat_gateway_ip.
#   2. Hairpin  the same for the public IP, so the public names also work from
#      this box and from the cluster behind it (cert-manager checks every
#      Let's Encrypt HTTP-01 challenge from inside before asking for it).
#      Connections that start on the gateway's own subnet are masqueraded, or
#      the reply would go straight back and never be un-NATed.
#   3. Forwarding  ip_forward on, and an accept for the forwarded traffic ahead
#      of whatever stands in its way: xdebbie's host firewall (which drops new
#      flows into the mesh bridge from any other interface), libvirt's
#      NAT-mode network (rejects them) and ufw (drops routed traffic).
# Outside clients are not masqueraded, so the Gateway still sees their address;
# that relies on this box being the cluster nodes' default route.
#
# Nothing here survives a reboot, and xdebbied and libvirt drop (3) when they
# rebuild their rules (service or network restart): run it again afterwards,
# e.g. from a boot unit ordered after xdebbied.
#
# Values come from the environment, else the file a previous run saved
# (/etc/default/aviary-nat, so a bare `sudo set-nat.sh` works from then on),
# else terraform.tfvars (TFVARS) -- the NAT box need not have the repo:
#   NAT_GATEWAY_IP  the public Gateway's LB address        (tfvars nat_gateway_ip)
#   PUBLIC_DOMAIN   resolved to find the public IP         (tfvars public_domain)
#   PUBLIC_IP       the public IP itself; "none" skips the hairpin rules
#   EXT_ADDRS       this box's LAN address(es), space separated
#                   (default: every address it has on the default route's subnet)
#   PORTS           default "80 443"
set -euo pipefail

TFVARS=${TFVARS:-$(dirname "$0")/../terraform.tfvars}
SAVED=/etc/default/aviary-nat
# A tfvars value, or nothing (no tfvars here is fine: || true keeps set -e quiet).
val() { { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\{0,1\}\([^\"#]*\)\"\{0,1\}.*/\1/p" "$TFVARS" 2>/dev/null || true; } | head -1 | sed 's/[[:space:]]*$//'; }
# A value saved by an earlier run, or nothing.
saved() { { sed -n "s/^$1=//p" "$SAVED" 2>/dev/null || true; } | head -1; }
die() { echo "set-nat: $*" >&2; exit 1; }

MODE=apply
case "${1:-}" in
    "") ;;
    -n) MODE=print ;;
    -d) MODE=delete ;;
    *) die "usage: $0 [-n | -d]" ;;
esac

export PATH=$PATH:/usr/sbin:/sbin
TABLE=aviary_nat     # our own nft table: replaced wholesale on every run
TAG=aviary-nat       # comment on the rules we add to other people's chains

GW=${NAT_GATEWAY_IP:-$(saved NAT_GATEWAY_IP)}
GW=${GW:-$(val nat_gateway_ip)}
PUBLIC_DOMAIN=${PUBLIC_DOMAIN:-$(saved PUBLIC_DOMAIN)}
PUBLIC_DOMAIN=${PUBLIC_DOMAIN:-$(val public_domain)}
PORTS=${PORTS:-$(saved PORTS)}
PORTS=${PORTS:-80 443}
NFT_PORTS="{ ${PORTS// /, } }"
IPT_PORTS=${PORTS// /,}

# run CMD...: do it, or in -n mode just show it.
run() { if [ "$MODE" = print ]; then echo "+ $*"; else "$@"; fi; }

# --- removal (also the first half of every install) --------------------------
# Rules in other people's nft chains and in iptables FORWARD are found by their tag.
# nft chains ("table chain") that turn away new flows into the bridge: xdebbied's
# host firewall and libvirt's NAT-mode network.
GUARD_CHAINS="xdebbie_host/forward libvirt_network/guest_input"
have_chain() { nft list chain ip "${1%/*}" "${1#*/}" >/dev/null 2>&1; }
ipt_forward() { command -v iptables >/dev/null && iptables -S FORWARD >/dev/null 2>&1; }

remove() {
    nft list table ip $TABLE >/dev/null 2>&1 && run nft delete table ip $TABLE
    for c in $GUARD_CHAINS; do
        have_chain "$c" || continue
        nft -a list chain ip "${c%/*}" "${c#*/}" | sed -n "s/.*comment \"$TAG\".*# handle \([0-9]*\)$/\1/p" |
            while read -r h; do run nft delete rule ip "${c%/*}" "${c#*/}" handle "$h"; done
    done
    if ipt_forward; then
        iptables -S FORWARD | sed -n "s/^-A \(.*--comment $TAG.*\)/\1/p" |
            while read -r rule; do eval "run iptables -D $rule"; done
    fi
    return 0
}

if [ "$MODE" = delete ]; then
    [ "$(id -u)" = 0 ] || die "run as root"
    remove
    echo "set-nat: removed"
    exit 0
fi

# --- what to NAT -------------------------------------------------------------
[ -n "$GW" ] || die "no gateway address. Give it once and it is remembered:
    sudo NAT_GATEWAY_IP=<aviary-nat's address> PUBLIC_DOMAIN=<domain> $0"

# The interface and connected subnet the Gateway is reached through.
GW_DEV=$(ip -4 route get "$GW" | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1)
ip -4 route get "$GW" | grep -q " via " && die "$GW is not on a network this box is attached to"
GW_NET=$(ip -4 -o route show dev "$GW_DEV" scope link | awk '{print $1; exit}')
[ -n "$GW_DEV" ] && [ -n "$GW_NET" ] || die "cannot find the network $GW is on"

# This box's addresses on the LAN the router forwards into: all of them on the
# default route's subnet (a box with two NICs there may be the DMZ host on either).
if [ -z "${EXT_ADDRS:-}" ]; then
    DEF_DEV=$(ip -4 route show default | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1)
    [ -n "$DEF_DEV" ] || die "no default route: set EXT_ADDRS"
    DEF_NET=$(ip -4 -o route show dev "$DEF_DEV" scope link | awk '{print $1; exit}')
    EXT_ADDRS=$(ip -4 -o addr show to "$DEF_NET" | awk '{sub(/\/.*/, "", $4); print $4}' | xargs)
fi
[ -n "$EXT_ADDRS" ] || die "no LAN address found: set EXT_ADDRS"

# The public IP, for the hairpin rules.
if [ -z "${PUBLIC_IP:-}" ] && [ -n "$PUBLIC_DOMAIN" ]; then
    PUBLIC_IP=$(getent ahostsv4 "aviary.$PUBLIC_DOMAIN" | awk '{print $1; exit}' || true)
fi
case "${PUBLIC_IP:-}" in
    "" | none) PUBLIC_IP="" ; echo "set-nat: no public IP (set PUBLIC_IP): skipping the hairpin rules" >&2 ;;
esac

DADDRS="{ $(echo "$EXT_ADDRS $PUBLIC_IP" | xargs | sed 's/ /, /g') }"

RULESET="table ip $TABLE {
    chain prerouting {
        type nat hook prerouting priority -105;
        ip daddr $DADDRS tcp dport $NFT_PORTS dnat to $GW
    }
    chain output {
        type nat hook output priority -105;
        ${PUBLIC_IP:+ip daddr $PUBLIC_IP tcp dport $NFT_PORTS dnat to $GW}
    }
    chain postrouting {
        type nat hook postrouting priority 95;
        ip saddr $GW_NET ip daddr $GW tcp dport $NFT_PORTS ct status dnat masquerade
    }
}"

echo "set-nat: tcp $PORTS on $(echo "$EXT_ADDRS $PUBLIC_IP" | xargs) -> $GW (via $GW_DEV, $GW_NET)"

if [ "$MODE" = print ]; then
    echo "+ sysctl -w net.ipv4.ip_forward=1"
    echo "+ nft -f - <<EOF"; echo "$RULESET"; echo "EOF"
    for c in $GUARD_CHAINS; do
        echo "+ (if it exists) nft insert rule ip ${c%/*} ${c#*/} oifname $GW_DEV ip daddr $GW tcp dport $NFT_PORTS counter accept comment \"$TAG\""
    done
    echo "+ (if iptables FORWARD exists) iptables -I FORWARD 1 -o $GW_DEV -d $GW -p tcp -m multiport --dports $IPT_PORTS -m comment --comment $TAG -j ACCEPT"
    echo "+ (if iptables FORWARD exists) iptables -I FORWARD 1 -i $GW_DEV -s $GW -p tcp -m multiport --sports $IPT_PORTS -m comment --comment $TAG -j ACCEPT"
    exit 0
fi

# --- install -----------------------------------------------------------------
[ "$(id -u)" = 0 ] || die "run as root (or -n to only print)"
command -v nft >/dev/null || die "nft not found"

remove
sysctl -q -w net.ipv4.ip_forward=1
printf '%s\n' "$RULESET" | nft -f -

# Let the forwarded traffic past the local firewalls. xdebbied drops, and
# libvirt's NAT-mode network rejects, new connections into the bridge; ufw
# drops forwarding by default. An accept in our own table would not override
# any of them (a drop in any chain is final), so the rule goes at the head of
# each of their chains.
for c in $GUARD_CHAINS; do
    have_chain "$c" || continue
    nft insert rule ip "${c%/*}" "${c#*/}" oifname "$GW_DEV" ip daddr "$GW" \
        tcp dport "$NFT_PORTS" counter accept comment "\"$TAG\""
    echo "set-nat: accept added to nft chain ${c%/*} ${c#*/}"
done
if ipt_forward; then
    iptables -I FORWARD 1 -o "$GW_DEV" -d "$GW" -p tcp -m multiport --dports "$IPT_PORTS" \
        -m comment --comment $TAG -j ACCEPT
    iptables -I FORWARD 1 -i "$GW_DEV" -s "$GW" -p tcp -m multiport --sports "$IPT_PORTS" \
        -m comment --comment $TAG -j ACCEPT
    echo "set-nat: accepts added to iptables FORWARD"
fi

# Remember what was used, so the next run (after a reboot, or an xdebbied
# restart) needs no arguments.
printf 'NAT_GATEWAY_IP=%s\nPUBLIC_DOMAIN=%s\nPORTS=%s\n' "$GW" "$PUBLIC_DOMAIN" "$PORTS" > "$SAVED"

echo "set-nat: done (settings saved in $SAVED). Check from outside: curl -sI http://aviary.${PUBLIC_DOMAIN:-<public_domain>}/"
