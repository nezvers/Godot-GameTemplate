# Shared by the vlan_*.sh scripts (sourced, not run). See README.md.
# Direct WireGuard tunnel via NetworkManager, no servers: both sides know each other's public address
# and send at the same time (keepalive), so each router/firewall lets the other's packets back in.

NAME=zsvlan                  # NM connection + interface name (and the tunnel name on Windows)
NET=10.77.0                  # host is .1, guests .2-.8
PORT=${VLAN_PORT:-51820}     # WireGuard UDP port, same on every machine
GAME_PORT=24565
STATE_HOST=${XDG_STATE_HOME:-$HOME/.local/state}/zs-vlan
STATE_GUEST=${XDG_STATE_HOME:-$HOME/.local/state}/zs-vlan-guest

die() { echo "$*" >&2; exit 1; }

# X25519 keys with openssl (no wireguard-tools needed): raw 32 bytes, base64.
b64key() { tail -c 32 | base64; }
genpriv() { openssl genpkey -algorithm X25519 -outform DER | b64key; }
pubkey() { base64 -d <<<"$1" | cat <(printf '\x30\x2e\x02\x01\x00\x30\x05\x06\x03\x2b\x65\x6e\x04\x22\x04\x20') - \
	| openssl pkey -inform DER -pubout -outform DER | b64key; }

# Public IPv6 = the source address the kernel uses toward the internet (no external lookup). "-" if none.
my_v6() {
	local a
	a=$(ip -6 route get 2606:4700:4700::1111 2>/dev/null | sed -n 's/.* src \([0-9a-f:]*\).*/\1/p')
	[[ -n $a && $a != fe80* && $a != fc* && $a != fd* ]] && echo "$a" || echo -
}
# Public IPv4 (fallback only): VLAN_IPV4=addr sets it, VLAN_IPV4=none skips; else one lookup at api.ipify.org.
my_v4() {
	local a
	if [ -n "${VLAN_IPV4:-}" ]; then [ "$VLAN_IPV4" = none ] && echo - || echo "$VLAN_IPV4"; return; fi
	a=$(curl -s4 --max-time 4 https://api.ipify.org 2>/dev/null || true)
	[[ $a =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$a" || echo -
}

# Invite/reply lines: "<prefix>.<base64 of space-separated fields>" - only public keys and addresses, safe for chat.
enc() { printf '%s.%s' "$1" "$(printf '%s' "$2" | base64 -w0)"; }
dec() { [[ $2 == "$1".* ]] || die "not a $1 line: $2"; base64 -d <<<"${2#*.}" 2>/dev/null || die "broken $1 line"; }

# Endpoint for a peer: IPv6 when both sides have it, else the peer's IPv4.  args: peer_v6 peer_v4 peer_port my_v6
pick_ep() {
	if [ "$1" != - ] && [ "$4" != - ]; then echo "[$1]:$3"
	elif [ "$2" != - ]; then echo "$2:$3"
	else return 1; fi
}

conn_exists() { nmcli -g NAME connection show | grep -qx "$NAME"; }

# Replace the NM connection with the WireGuard config on stdin.
nm_apply() {
	local tmp="$STATE/$NAME.conf"   # NM names the connection after the file
	(umask 077; cat >"$tmp")
	if conn_exists; then nmcli connection delete "$NAME" >/dev/null; fi
	nmcli connection import type wireguard file "$tmp" >/dev/null || { rm -f "$tmp"; die "nmcli import failed"; }
	rm -f "$tmp"   # private key now only in NM's root-only store (and $STATE/*.key)
	nmcli connection modify "$NAME" ipv6.method disabled connection.autoconnect yes
	nmcli connection up "$NAME" >/dev/null
}

# Open ufw rules (sudo) if ufw is active; remember which ones we added so teardown removes only those.
fw_open() {
	local r st
	if ! systemctl is-active -q ufw; then echo "ufw inactive, nothing changed" >"$STATE/firewall"; return; fi
	echo "ufw is active: sudo needed to allow: $*"
	st=$(sudo ufw status) || { echo "sudo failed, ufw untouched - peers may be blocked" | tee "$STATE/firewall"; return; }
	for r in "$@"; do
		if [[ $r == "in on "* ]]; then grep -q " on ${r#in on }" <<<"$st" && continue
		else grep -q "^$r " <<<"$st" && continue; fi
		# shellcheck disable=SC2086
		sudo ufw allow $r comment zs-vlan >/dev/null && echo "$r" >>"$STATE/ufw_rules"
	done
	if [ -s "$STATE/ufw_rules" ]; then echo "ufw rules added: $(paste -sd, "$STATE/ufw_rules")" >"$STATE/firewall"
	else echo "ufw already allowed it, nothing changed" >"$STATE/firewall"; fi
}

# Undo everything for one role: NM connection, ufw rules we added, keys/state.
teardown() {
	if conn_exists; then nmcli connection delete "$NAME" >/dev/null && echo "removed NM connection $NAME"; else echo "no NM connection $NAME"; fi
	if [ -s "$STATE/ufw_rules" ]; then
		echo "removing ufw rules (sudo)"
		while IFS= read -r r; do
			# shellcheck disable=SC2086
			sudo ufw delete allow $r >/dev/null && echo "  removed ufw: $r" || echo "  FAILED ufw: $r (fix by hand: sudo ufw status numbered)"
		done <"$STATE/ufw_rules"
	fi
	if [ -d "$STATE" ]; then rm -rf "$STATE" && echo "removed $STATE"; fi
	echo "done."
}

ping_st() { ping -c1 -W1 "$1" >/dev/null 2>&1 && echo "online" || echo "no reply"; }
