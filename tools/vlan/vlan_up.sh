#!/usr/bin/env bash
# Host side. See README.md.
#   vlan_up.sh                create the virtual LAN, or show its info + the invite line if it exists
#   vlan_up.sh add <reply>    add (or update) a guest from the reply line they sent back
#   vlan_up.sh remove <N>     remove guest 10.77.0.N
set -euo pipefail
. "$(dirname "$0")/lib.sh"
STATE=$STATE_HOST
[ -d "$STATE_GUEST" ] && die "this PC is a guest ($STATE_GUEST); run vlan_disconnect.sh first"

host_conf() {
	local f pub ep
	printf '[Interface]\nPrivateKey = %s\nAddress = %s.1/24\nListenPort = %s\n' "$(cat "$STATE/host.key")" "$NET" "$PORT"
	for f in "$STATE"/peers/*; do
		[ -e "$f" ] || continue
		read -r pub ep <"$f"
		printf '\n[Peer]\nPublicKey = %s\nAllowedIPs = %s.%s/32\nEndpoint = %s\nPersistentKeepalive = 25\n' "$pub" "$NET" "${f##*/}" "$ep"
	done
}

next_slot() { local n; for n in 2 3 4 5 6 7 8; do [ -e "$STATE/peers/$n" ] || { echo "$n"; return; }; done; echo -; }

show() {
	local v6 v4 f pub ep n slot hpub
	v6=$(my_v6); v4=$(my_v4); hpub=$(pubkey "$(cat "$STATE/host.key")")
	echo "== zs-vlan host (WireGuard via NetworkManager, no servers) =="
	echo "interface : $NAME ($(nmcli -g GENERAL.STATE device show "$NAME" 2>/dev/null || echo down))"
	echo "this PC   : $NET.1   <- guests join the game at $NET.1:$GAME_PORT"
	echo "public v6 : $v6"
	echo "public v4 : $v4  (fallback)"
	echo "firewall  : $(cat "$STATE/firewall" 2>/dev/null || echo "not touched")"
	echo
	echo "guests:"
	n=0
	for f in "$STATE"/peers/*; do
		[ -e "$f" ] || continue
		read -r pub ep <"$f"; n=1
		echo "  $NET.${f##*/}  via $ep  ($(ping_st "$NET.${f##*/}"))"
	done
	[ $n = 1 ] || echo "  none yet"
	echo
	slot=$(next_slot)
	if [ "$slot" = - ]; then echo "all 7 guest slots used (vlan_up.sh remove <N> frees one)"; return; fi
	echo "invite for the next guest ($NET.$slot) - send this line, it holds only public info:"
	echo
	enc zsi1 "$hpub $PORT $slot $v6 $v4"; echo
	echo
	echo "guest runs:  Windows: powershell -ExecutionPolicy Bypass -File vlan_connect.ps1 <invite>"
	echo "             Linux:   tools/vlan/vlan_connect.sh <invite>"
	echo "then you:    tools/vlan/vlan_up.sh add <reply line they send back>"
}

add_peer() {
	local slot gpub gport gv6 gv4 ep old
	read -r slot gpub gport gv6 gv4 <<<"$(dec zsr1 "$1")"
	[[ $slot =~ ^[2-8]$ && ${#gpub} = 44 && $gport =~ ^[0-9]+$ ]] || die "broken reply line"
	if [ -e "$STATE/peers/$slot" ]; then
		read -r old _ <"$STATE/peers/$slot"
		[ "$old" = "$gpub" ] || die "slot $NET.$slot is taken by another guest; rerun vlan_up.sh for a fresh invite and have them reconnect with it"
	fi
	ep=$(pick_ep "$gv6" "$gv4" "$gport" "$(my_v6)") || die "guest sent no usable address"
	mkdir -p "$STATE/peers"
	echo "$gpub $ep" >"$STATE/peers/$slot"
	conf=$(host_conf); nm_apply <<<"$conf"
	echo "guest $NET.$slot added via $ep"; echo
}

case "${1:-}" in
"")
	if conn_exists; then
		[ -f "$STATE/host.key" ] || die "connection $NAME exists but $STATE is missing; run vlan_down.sh and retry"
		nmcli connection up "$NAME" >/dev/null 2>&1 || true
	else
		mkdir -p "$STATE/peers"; chmod 700 "$STATE"
		(umask 077; genpriv >"$STATE/host.key")
		conf=$(host_conf); nm_apply <<<"$conf"
		fw_open "$PORT/udp" "in on $NAME"
		echo "created."; echo
	fi
	show ;;
add)
	[ -n "${2:-}" ] || die "usage: vlan_up.sh add <reply>"
	conn_exists && [ -f "$STATE/host.key" ] || die "no virtual LAN yet; run vlan_up.sh first"
	add_peer "$2"; show ;;
remove)
	[[ ${2:-} =~ ^[2-8]$ ]] || die "usage: vlan_up.sh remove <2..8>"
	[ -e "$STATE/peers/$2" ] || die "no guest $NET.$2"
	rm "$STATE/peers/$2"; conf=$(host_conf); nm_apply <<<"$conf"
	echo "guest $NET.$2 removed"; echo; show ;;
*) die "usage: vlan_up.sh [add <reply> | remove <N>]" ;;
esac
