#!/usr/bin/env bash
# Guest side on Linux (NetworkManager). See README.md.
#   vlan_connect.sh <invite>   join the host's virtual LAN (rerun with a new invite if the host's address changed)
#   vlan_connect.sh            show info + the reply line to send back to the host
set -euo pipefail
. "$(dirname "$0")/lib.sh"
STATE=$STATE_GUEST
[ -d "$STATE_HOST" ] && die "this PC is a host ($STATE_HOST); run vlan_down.sh first"

guest_conf() {
	local hpub hport slot hv6 hv4 ep
	read -r hpub hport slot hv6 hv4 <<<"$(dec zsi1 "$(cat "$STATE/invite")")"
	ep=$(pick_ep "$hv6" "$hv4" "$hport" "$(my_v6)") || die "host has no address usable from here (no IPv6 on one side, no IPv4 in invite)"
	printf '[Interface]\nPrivateKey = %s\nAddress = %s.%s/24\nListenPort = %s\n' "$(cat "$STATE/guest.key")" "$NET" "$slot" "$PORT"
	printf '\n[Peer]\nPublicKey = %s\nAllowedIPs = %s.1/32\nEndpoint = %s\nPersistentKeepalive = 25\n' "$hpub" "$NET" "$ep"
}

show() {
	local hpub hport slot hv6 hv4 gpub
	read -r hpub hport slot hv6 hv4 <<<"$(dec zsi1 "$(cat "$STATE/invite")")"
	gpub=$(pubkey "$(cat "$STATE/guest.key")")
	echo "== zs-vlan guest (WireGuard via NetworkManager, no servers) =="
	echo "interface : $NAME ($(nmcli -g GENERAL.STATE device show "$NAME" 2>/dev/null || echo down))"
	echo "this PC   : $NET.$slot"
	echo "host      : $NET.1 via $(pick_ep "$hv6" "$hv4" "$hport" "$(my_v6)" || echo "?")  ($(ping_st "$NET.1"))"
	echo "game      : join $NET.1:$GAME_PORT"
	echo "firewall  : $(cat "$STATE/firewall" 2>/dev/null || echo "not touched")"
	echo
	echo "reply - send this line back to the host (they run: vlan_up.sh add <reply>):"
	echo
	enc zsr1 "$slot $gpub $PORT $(my_v6) $(my_v4)"; echo
}

if [ -n "${1:-}" ]; then
	dec zsi1 "$1" >/dev/null
	mkdir -p "$STATE"; chmod 700 "$STATE"
	[ -f "$STATE/guest.key" ] || (umask 077; genpriv >"$STATE/guest.key")   # same key on rejoin, so the host's entry stays valid
	printf '%s\n' "$1" >"$STATE/invite"
	conf=$(guest_conf) || exit 1; nm_apply <<<"$conf"
	[ -f "$STATE/firewall" ] || fw_open "$PORT/udp" "in on $NAME"   # tunnel open too, so this PC can host the game
	echo "connected (host sees you once they add your reply)."; echo
else
	conn_exists && [ -f "$STATE/invite" ] || die "usage: vlan_connect.sh <invite line from the host>"
	nmcli connection up "$NAME" >/dev/null 2>&1 || true
fi
show
