@abstract
## How peers reach each other. Gameplay only ever sees the MultiplayerPeer;
## ENetTransport is direct IP (listen server / dedicated server), a Steam
## transport (GodotSteam's SteamMultiplayerPeer + lobbies) can slot in later.
class_name NetTransport
extends RefCounted

## max_clients excludes the host itself.
@abstract func create_host(port:int, max_clients:int)->MultiplayerPeer
@abstract func create_client(address:String, port:int)->MultiplayerPeer

## Addresses to tell a friend, best first, as [{"label", "address"}]
## (may be slow: call from a thread).
func share_addresses(_port:int)->Array:
	return []

## A peer just connected (host: a guest, guest: the host, id 1).
func tune_peer(_peer:MultiplayerPeer, _peer_id:int)->void:
	pass

## Called once hosting stops (undo port mappings and similar).
func close()->void:
	pass
