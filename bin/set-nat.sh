#!/usr/bin/env bash
# NAT the outside world to the public Gateway (aviary-nat, nat_gateway_ip) and,
# when SMTP_IP / JVB_IP are given, mail to the cluster's SMTP load balancer
# and conference media to the Jitsi video bridge.
#
# Run this as root ON THE BOX THE ROUTER SENDS INBOUND TRAFFIC TO (its DMZ or
# port-forward host), which must also route to the cluster's LB network:
#
#   sudo bin/set-nat.sh        # install (safe to re-run: replaces its own rules)
#   bin/set-nat.sh -n          # print what would be done, change nothing
#   sudo bin/set-nat.sh -d     # remove everything it installed
#
# What it sets up -- for tcp 80 and 443 to the Gateway, and for SMTP (25 plain
# with STARTTLS, 465 implicit TLS, 587 submission) to SMTP_IP, and for Jitsi
# media (udp 10000) to JVB_IP:
#   1. DNAT   traffic addressed to this box's LAN address(es) -> the destination.
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
#   SMTP_IP         the mail LoadBalancer's address (the axigen-mail-smtp-public
#                   Service, tfvars smtp_load_balancer_ip); unset = no mail
#                   forwarding; "none" forgets a saved one
#   SMTP_PORTS      default "25 465 587"
#   JVB_IP          the Jitsi video bridge's LoadBalancer address (tfvars
#                   jitsi_jvb_load_balancer_ip); unset = none; "none" forgets it
#   JVB_PORTS       udp, default "10000"
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
SMTP_IP=${SMTP_IP:-$(saved SMTP_IP)}
SMTP_IP=${SMTP_IP:-$(val smtp_load_balancer_ip)}
[ "$SMTP_IP" != none ] || SMTP_IP=""
SMTP_PORTS=${SMTP_PORTS:-$(saved SMTP_PORTS)}
SMTP_PORTS=${SMTP_PORTS:-25 465 587}
JVB_IP=${JVB_IP:-$(saved JVB_IP)}
JVB_IP=${JVB_IP:-$(val jitsi_jvb_load_balancer_ip)}
[ "$JVB_IP" != none ] || JVB_IP=""
JVB_PORTS=${JVB_PORTS:-$(saved JVB_PORTS)}
JVB_PORTS=${JVB_PORTS:-10000}

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

# What goes where: one "protocol address ports..." line per destination.
TARGETS="tcp $GW $PORTS"
[ -z "$SMTP_IP" ] || TARGETS="$TARGETS
tcp $SMTP_IP $SMTP_PORTS"
[ -z "$JVB_IP" ] || TARGETS="$TARGETS
udp $JVB_IP $JVB_PORTS"

# The interface and connected subnet the destinations are reached through.
dev_of() { ip -4 route get "$1" | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1; }
GW_DEV=$(dev_of "$GW")
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

nftset() { echo "{ $(echo "$*" | xargs | sed 's/ /, /g') }"; }   # 80 443 -> { 80, 443 }
iptset() { echo "$*" | xargs | sed 's/ /,/g'; }                  # 80 443 -> 80,443
DADDRS=$(nftset $EXT_ADDRS $PUBLIC_IP)

PRE="" OUT="" POST=""
while read -r proto ip ports; do
    [ -n "$ip" ] || continue
    ip -4 route get "$ip" | grep -q " via " && die "$ip is not on a network this box is attached to"
    [ "$(dev_of "$ip")" = "$GW_DEV" ] || die "$ip is not on the same network as $GW ($GW_DEV)"
    p=$(nftset $ports)
    PRE="$PRE        ip daddr $DADDRS $proto dport $p dnat to $ip
"
    [ -z "$PUBLIC_IP" ] || OUT="$OUT        ip daddr $PUBLIC_IP $proto dport $p dnat to $ip
"
    POST="$POST        ip saddr $GW_NET ip daddr $ip $proto dport $p ct status dnat masquerade
"
    echo "set-nat: $proto $ports on $(echo "$EXT_ADDRS $PUBLIC_IP" | xargs) -> $ip (via $GW_DEV, $GW_NET)"
done <<EOF
$TARGETS
EOF

RULESET="table ip $TABLE {
    chain prerouting {
        type nat hook prerouting priority -105;
$PRE    }
    chain output {
        type nat hook output priority -105;
$OUT    }
    chain postrouting {
        type nat hook postrouting priority 95;
$POST    }
}"

if [ "$MODE" = print ]; then
    echo "+ sysctl -w net.ipv4.ip_forward=1"
    echo "+ nft -f - <<EOF"; echo "$RULESET"; echo "EOF"
    while read -r proto ip ports; do
        [ -n "$ip" ] || continue
        for c in $GUARD_CHAINS; do
            echo "+ (if it exists) nft insert rule ip ${c%/*} ${c#*/} oifname $GW_DEV ip daddr $ip $proto dport $(nftset $ports) counter accept comment \"$TAG\""
        done
        echo "+ (if iptables FORWARD exists) iptables -I FORWARD 1 -o $GW_DEV -d $ip -p $proto -m multiport --dports $(iptset $ports) -m comment --comment $TAG -j ACCEPT"
        echo "+ (if iptables FORWARD exists) iptables -I FORWARD 1 -i $GW_DEV -s $ip -p $proto -m multiport --sports $(iptset $ports) -m comment --comment $TAG -j ACCEPT"
    done <<EOF
$TARGETS
EOF
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
while read -r proto ip ports; do
    [ -n "$ip" ] || continue
    for c in $GUARD_CHAINS; do
        have_chain "$c" || continue
        nft insert rule ip "${c%/*}" "${c#*/}" oifname "$GW_DEV" ip daddr "$ip" \
            "$proto" dport "$(nftset $ports)" counter accept comment "\"$TAG\""
        echo "set-nat: accept for $ip added to nft chain ${c%/*} ${c#*/}"
    done
    if ipt_forward; then
        iptables -I FORWARD 1 -o "$GW_DEV" -d "$ip" -p "$proto" -m multiport --dports "$(iptset $ports)" \
            -m comment --comment $TAG -j ACCEPT
        iptables -I FORWARD 1 -i "$GW_DEV" -s "$ip" -p "$proto" -m multiport --sports "$(iptset $ports)" \
            -m comment --comment $TAG -j ACCEPT
        echo "set-nat: accepts for $ip added to iptables FORWARD"
    fi
done <<EOF
$TARGETS
EOF

# Remember what was used, so the next run (after a reboot, or an xdebbied
# restart) needs no arguments.
printf 'NAT_GATEWAY_IP=%s\nPUBLIC_DOMAIN=%s\nPORTS=%s\nSMTP_IP=%s\nSMTP_PORTS=%s\nJVB_IP=%s\nJVB_PORTS=%s\n' \
    "$GW" "$PUBLIC_DOMAIN" "$PORTS" "$SMTP_IP" "$SMTP_PORTS" "$JVB_IP" "$JVB_PORTS" > "$SAVED"

echo "set-nat: done (settings saved in $SAVED). Check from outside: curl -sI http://aviary.${PUBLIC_DOMAIN:-<public_domain>}/"
