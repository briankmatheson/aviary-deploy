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
#      of the rejects libvirt (NAT-mode network) and ufw put in its way.
# Outside clients are not masqueraded, so the Gateway still sees their address;
# that relies on this box being the cluster nodes' default route.
#
# Nothing here survives a reboot, and libvirt drops (3) when it rebuilds its
# rules (network or libvirtd restart): run it again, e.g. from a boot unit.
#
# Values come from terraform.tfvars (TFVARS) when it is there, else the
# environment -- the NAT box need not have the repo's tfvars:
#   NAT_GATEWAY_IP  the public Gateway's LB address        (tfvars nat_gateway_ip)
#   PUBLIC_DOMAIN   resolved to find the public IP         (tfvars public_domain)
#   PUBLIC_IP       the public IP itself; "none" skips the hairpin rules
#   EXT_ADDRS       this box's LAN address(es), space separated
#                   (default: every address it has on the default route's subnet)
#   PORTS           default "80 443"
set -euo pipefail

TFVARS=${TFVARS:-$(dirname "$0")/../terraform.tfvars}
val() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\{0,1\}\([^\"#]*\)\"\{0,1\}.*/\1/p" "$TFVARS" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//'; }
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

GW=${NAT_GATEWAY_IP:-$(val nat_gateway_ip)}
PUBLIC_DOMAIN=${PUBLIC_DOMAIN:-$(val public_domain)}
PORTS=${PORTS:-80 443}
NFT_PORTS="{ ${PORTS// /, } }"
IPT_PORTS=${PORTS// /,}

# run CMD...: do it, or in -n mode just show it.
run() { if [ "$MODE" = print ]; then echo "+ $*"; else "$@"; fi; }

# --- removal (also the first half of every install) --------------------------
# Rules in libvirt's nft chain and in iptables FORWARD are found by their tag.
libvirt_chain() { nft list chain ip libvirt_network guest_input >/dev/null 2>&1; }
ipt_forward() { command -v iptables >/dev/null && iptables -S FORWARD >/dev/null 2>&1; }

remove() {
    nft list table ip $TABLE >/dev/null 2>&1 && run nft delete table ip $TABLE
    if libvirt_chain; then
        nft -a list chain ip libvirt_network guest_input | sed -n "s/.*comment \"$TAG\".*# handle \([0-9]*\)$/\1/p" |
            while read -r h; do run nft delete rule ip libvirt_network guest_input handle "$h"; done
    fi
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
[ -n "$GW" ] || die "no gateway address: set NAT_GATEWAY_IP (or nat_gateway_ip in $TFVARS)"

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
    echo "+ (if libvirt's nft table exists) nft insert rule ip libvirt_network guest_input oifname $GW_DEV ip daddr $GW tcp dport $NFT_PORTS counter accept comment \"$TAG\""
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

# Let the forwarded traffic past the local firewalls. libvirt's NAT-mode
# network rejects new connections into its bridge; ufw drops forwarding by
# default. An accept in our own table would not override either, so the rule
# goes at the head of their chains.
if libvirt_chain; then
    nft insert rule ip libvirt_network guest_input oifname "$GW_DEV" ip daddr "$GW" \
        tcp dport "$NFT_PORTS" counter accept comment "\"$TAG\""
    echo "set-nat: accept added to libvirt's guest_input chain"
fi
if ipt_forward; then
    iptables -I FORWARD 1 -o "$GW_DEV" -d "$GW" -p tcp -m multiport --dports "$IPT_PORTS" \
        -m comment --comment $TAG -j ACCEPT
    iptables -I FORWARD 1 -i "$GW_DEV" -s "$GW" -p tcp -m multiport --sports "$IPT_PORTS" \
        -m comment --comment $TAG -j ACCEPT
    echo "set-nat: accepts added to iptables FORWARD"
fi

echo "set-nat: done. Check from outside: curl -sI http://aviary.${PUBLIC_DOMAIN:-<public_domain>}/"
