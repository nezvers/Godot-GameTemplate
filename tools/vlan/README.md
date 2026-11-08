# zs-vlan: a virtual LAN for co-op over the internet

A direct WireGuard tunnel between the host and each guest. It needs **no port forwarding, no accounts, and no servers**, and it is free.

Both sides know each other's public address and send to each other at the same time (a keepalive every 25s). Each router sees outgoing traffic, so it lets the other side's packets back in. This is UDP hole punching.

- **IPv6 is the default.** It is used whenever both sides have a public IPv6. There is no address translation, so it works almost always.
- **IPv4 is the fallback.** It works only if both routers keep the UDP port number unchanged. It never works behind CGNAT. Finding your own public IPv4 needs one lookup at `api.ipify.org`. Set `VLAN_IPV4=<addr>` to give it yourself, or `VLAN_IPV4=none` to skip IPv4.

| | address | game |
|---|---|---|
| host | `10.77.0.1` | hosts on port `24565` |
| guests | `10.77.0.2` – `10.77.0.8` | join `10.77.0.1:24565` |

## Setup

1. **Host:** run `tools/vlan/vlan_up.sh`. It prints an **invite** line (`zsi1.…`). Send it to the guest. It contains only public keys and addresses.
2. **Guest:** run the connect script with the invite (see the commands below). It prints a **reply** line (`zsr1.…`). Send it back to the host.
3. **Host:** run `tools/vlan/vlan_up.sh add <reply>`.
4. **Check:** rerun the scripts with no arguments. When the guest shows `online` on the host and the handshake shows on the guest, the tunnel is up.
5. **Play:** the guest joins `10.77.0.1:24565` in-game.

Each further guest gets a fresh invite: rerun `vlan_up.sh` and it prints one for the next free address.

If a public address changes (home IPs change sometimes), the tunnel breaks:
- **Host's address changed:** the host reruns `vlan_up.sh`, and the guest runs connect again with the new invite.
- **Guest's address changed:** the guest reruns connect to get a new reply, and the host runs `add` with it again.

Keys are kept until teardown, so a rejoin doesn't need a new slot.

## Commands

### Host (Omarchy / Linux with NetworkManager)

| command | does |
|---|---|
| `tools/vlan/vlan_up.sh` | Creates the tunnel. If it already exists, shows its info, the guests and their status, and the next invite. |
| `tools/vlan/vlan_up.sh add <reply>` | Adds a guest, or updates one that has the same key. |
| `tools/vlan/vlan_up.sh remove <N>` | Removes guest `10.77.0.N`. |
| `tools/vlan/vlan_down.sh` | Removes everything `vlan_up.sh` made. |

### Guest, Windows (PowerShell; asks for admin)

| command | does |
|---|---|
| `powershell -ExecutionPolicy Bypass -File vlan_connect.ps1 <invite>` | Joins. It also installs WireGuard via winget if missing and adds firewall rules. |
| `powershell -ExecutionPolicy Bypass -File vlan_connect.ps1` | Shows info, the handshake, and the reply line. |
| `powershell -ExecutionPolicy Bypass -File vlan_disconnect.ps1` | Removes everything `vlan_connect.ps1` made, and uninstalls WireGuard if the connect script installed it. |

### Guest, Linux (NetworkManager)

| command | does |
|---|---|
| `tools/vlan/vlan_connect.sh <invite>` | Joins. |
| `tools/vlan/vlan_connect.sh` | Shows info and the reply line. |
| `tools/vlan/vlan_disconnect.sh` | Removes everything `vlan_connect.sh` made. |

One PC is either a host or a guest, never both.

## What gets changed, and what teardown removes

**Linux** (`vlan_up.sh` / `vlan_connect.sh`):
- **Network:** an NM connection and interface named `zsvlan`, set to autoconnect, so it comes back after a reboot until teardown. No sudo is needed for this part, since polkit lets the desktop user change NetworkManager settings.
- **Firewall:** only if ufw is active, and this step uses sudo. Host and guest both get `allow 51820/udp` and `allow in on zsvlan`, so either PC can host the game. The rules are tagged with the comment `zs-vlan`. Only rules the script actually added are recorded, and only those are removed.
- **State:** keys and state live in `~/.local/state/zs-vlan` (host) or `~/.local/state/zs-vlan-guest` (guest), with mode 700. The host's private key is also kept in NetworkManager's root-only store.
- **Packages:** no packages are installed. Keys are made with `openssl`, and NetworkManager has WireGuard built in.

**Windows** (`vlan_connect.ps1`):
- **Software:** the official WireGuard client, but only if it is missing. Teardown uninstalls it only if this script installed it.
- **Tunnel:** a service named `WireGuardTunnel$zsvlan`.
- **Firewall:** rules in the group `zs-vlan`: inbound UDP 51820, and everything from `10.77.0.0/24` (ping, and hosting the game later).
- **State:** keys and state live in `C:\ProgramData\zs-vlan`, readable only by admins and SYSTEM.

Teardown (`vlan_down.sh`, `vlan_disconnect.sh`, `vlan_disconnect.ps1`) removes all of the above, which puts the machine back the way it was.

## Settings (environment variables, all scripts)

| var | default | |
|---|---|---|
| `VLAN_PORT` | `51820` | WireGuard UDP port. Use the same value on every machine. |
| `VLAN_IPV4` | auto (`api.ipify.org`) | Public IPv4 to advertise, or `none` to skip IPv4. |

## Limits

- **Guests reach only the VLAN host, not each other.** Any PC can host the game for the VLAN host, so with 2 machines either one can host. With 3+ machines the game must run on the VLAN host, or IP forwarding needs adding.
- **Some setups can't be reached without a relay server:** no IPv6 on one side plus a strict or CGNAT IPv4 router on either side. The fallback for those players is a relay, such as the Steam transport planned in `addons/top_down/design_document/multiplayer.md`.
- **The in-game invite list hides VPN interfaces,** so take the `10.77.0.1` address from here.
- **To check whether a machine has IPv6,** open https://test-ipv6.com.
