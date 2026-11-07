## Autoload: the co-op session. Host-authoritative: the host (or later a dedicated
## server) owns the world, guests send requests. Offline the default
## OfflineMultiplayerPeer makes this machine the authority, so gameplay code checks
## Net.is_authority() and works the same in single player.
##
## Joining: guest connects -> sends _hello {protocol, game version, profile} ->
## host checks version, free slot and that it is accepting (home base lobby) ->
## _welcome {slot, roster} or _rejected {reason}. Every roster change is
## broadcast with _roster.
##
## Security: object decoding stays off, guests only send plain values, and every
## any_peer RPC checks its sender and arguments on the host.
extends Node

const MAX_PLAYERS:int = PlayerRegistry.MAX_PLAYERS
const DEFAULT_PORT:int = 24565
## Bump whenever an RPC or message layout changes.
const PROTOCOL_VERSION:int = 1
const CONNECT_TIMEOUT:float = 8.0
const HELLO_TIMEOUT:float = 5.0
const MAX_NAME_LENGTH:int = 24
const REJECT_GRACE:float = 1.0

enum State {OFFLINE, HOSTING, CONNECTING, JOINED}

signal state_changed
## Host and guests: someone joined or left (RunSession.players already updated).
signal roster_changed
## Guest: the attempt failed or the host closed the session.
signal connection_failed(reason:String)
signal session_ended(reason:String)
## Host: addresses to share ([{"label", "address"}]), once UPnP/LAN lookup is done.
signal share_addresses_ready(addresses:Array)

var state:State = State.OFFLINE
var transport:NetTransport = ENetTransport.new()
var port:int = DEFAULT_PORT
## Host: guests may join right now (the home base lobby opens it).
var accepting:bool = true
var share_addresses:Array = []
## Player sync and room following (/root/Net/Players on every peer).
var players:NetPlayers
## Enemies, loot, shots and fights (/root/Net/Entities).
var entities:NetEntities

## Host: peer_id -> seconds left to say hello before being dropped.
var _pending_hello:Dictionary = {}
var _connect_time_left:float
var _share_thread:Thread

func _ready()->void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_secure(multiplayer)
	players = NetPlayers.new()
	players.name = "Players"
	add_child(players)
	entities = NetEntities.new()
	entities.name = "Entities"
	add_child(entities)

func _secure(api:MultiplayerAPI)->void:
	if api is SceneMultiplayer:
		(api as SceneMultiplayer).allow_object_decoding = false

func is_online()->bool:
	return state == State.HOSTING || state == State.JOINED

## This machine decides what happens in the world (offline, host or server).
func is_authority()->bool:
	return state != State.JOINED && state != State.CONNECTING

func is_host()->bool:
	return state == State.HOSTING

func is_guest()->bool:
	return state == State.JOINED

func local_peer_id()->int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

# --- Host -------------------------------------------------------------------

func host(at_port:int = DEFAULT_PORT)->Error:
	if state != State.OFFLINE:
		return ERR_ALREADY_IN_USE
	var _peer:MultiplayerPeer = transport.create_host(at_port, MAX_PLAYERS - 1)
	if _peer == null:
		return ERR_CANT_CREATE
	port = at_port
	multiplayer.multiplayer_peer = _peer
	var _local:PlayerState = RunSession.local_player()
	_local.peer_id = 1
	_set_state(State.HOSTING)
	_lookup_share_addresses()
	roster_changed.emit()
	return OK

func _lookup_share_addresses()->void:
	share_addresses = []
	_share_thread = Thread.new()
	_share_thread.start(func ()->void:
		var _list:Array = transport.share_addresses(port)
		_publish_addresses.call_deferred(_list))

func _publish_addresses(list:Array)->void:
	if _share_thread != null:
		_share_thread.wait_to_finish()
		_share_thread = null
	if state != State.HOSTING:
		return
	share_addresses = list
	share_addresses_ready.emit(list)

func kick(slot:int, reason:String = "Kicked by host")->void:
	if !is_host():
		return
	var _state:PlayerState = RunSession.players.get_state(slot)
	if _state == null || _state.is_local:
		return
	_rejected.rpc_id(_state.peer_id, reason)
	_drop_peer_later(_state.peer_id)

## Lets the reliable _rejected reason reach the guest first; a well-behaved guest
## closes on its own, this catches the rest.
func _drop_peer_later(peer_id:int)->void:
	get_tree().create_timer(REJECT_GRACE).timeout.connect(_drop_peer.bind(peer_id))

func _drop_peer(peer_id:int)->void:
	if !is_host() || !multiplayer.get_peers().has(peer_id):
		return
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var _enet:ENetMultiplayerPeer = multiplayer.multiplayer_peer
		_enet.disconnect_peer(peer_id)

func _on_peer_connected(peer_id:int)->void:
	if is_host():
		_pending_hello[peer_id] = HELLO_TIMEOUT

func _on_peer_disconnected(peer_id:int)->void:
	_pending_hello.erase(peer_id)
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local && _state.peer_id == peer_id:
			RunSession.players.remove(_state.slot)
	if is_host():
		_broadcast_roster()
	roster_changed.emit()

## Guest -> host, once, right after connecting.
@rpc("any_peer", "call_remote", "reliable")
func _hello(info:Dictionary)->void:
	if !is_host():
		return
	var _peer:int = multiplayer.get_remote_sender_id()
	if !_pending_hello.has(_peer):
		return
	_pending_hello.erase(_peer)
	var _reason:String = _check_hello(info)
	if !_reason.is_empty():
		_rejected.rpc_id(_peer, _reason)
		_drop_peer_later(_peer)
		return
	var _slot:int = RunSession.players.free_slot()
	var _profile:String = str(info.profile_id)
	var _name:String = _clean_name(str(info.name))
	# Two games on one machine (or a copied save) share a profile: still welcome,
	# keyed apart so the run save can tell them back apart.
	if RunSession.players.find_profile(_profile) != null:
		_profile = "%s#%d" % [_profile, _slot]
		_name = "%s %d" % [_name, _slot + 1]
	var _guest:PlayerState = PlayerState.create_remote(_profile, _name, _slot)
	_guest.peer_id = _peer
	RunSession.players.add(_guest)
	_welcome.rpc_id(_peer, _slot, _roster())
	_broadcast_roster()
	roster_changed.emit()

func _check_hello(info:Dictionary)->String:
	if int(info.get("protocol", -1)) != PROTOCOL_VERSION || str(info.get("game_version", "")) != _game_version():
		return "Different game version (host has %s)" % _game_version()
	if !accepting:
		return "The host isn't in the home base"
	var _id:String = str(info.get("profile_id", ""))
	if _id.length() < 8 || _id.length() > 64:
		return "Bad profile"
	if RunSession.players.free_slot() < 0:
		return "Session is full (%d players)" % MAX_PLAYERS
	return ""

func _roster()->Array:
	var _list:Array = []
	for _state:PlayerState in RunSession.players.all():
		_list.append({"slot": _state.slot, "peer_id": _state.peer_id, "profile_id": _state.profile_id, "name": _state.display_name})
	return _list

func _broadcast_roster()->void:
	var _list:Array = _roster()
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local:
			_roster_update.rpc_id(_state.peer_id, _list)

# --- Guest ------------------------------------------------------------------

## address: "host" or "host:port"
func join(address:String)->Error:
	if state != State.OFFLINE:
		return ERR_ALREADY_IN_USE
	var _target:Dictionary = parse_address(address)
	if _target.is_empty():
		return ERR_INVALID_PARAMETER
	var _peer:MultiplayerPeer = transport.create_client(_target.host, _target.port)
	if _peer == null:
		return ERR_CANT_CONNECT
	port = _target.port
	multiplayer.multiplayer_peer = _peer
	_connect_time_left = CONNECT_TIMEOUT
	_set_state(State.CONNECTING)
	return OK

## {"host", "port"} or {} when the text isn't an address.
static func parse_address(text:String)->Dictionary:
	var _text:String = text.strip_edges()
	if _text.is_empty() || _text.contains(" "):
		return {}
	var _host:String = _text
	var _port:int = DEFAULT_PORT
	var _colon:int = _text.rfind(":")
	if _colon > 0:
		var _port_text:String = _text.substr(_colon + 1)
		if !_port_text.is_valid_int():
			return {}
		_port = int(_port_text)
		_host = _text.substr(0, _colon)
	if _port < 1 || _port > 65535 || _host.is_empty():
		return {}
	return {"host": _host, "port": _port}

func _on_connected_to_server()->void:
	_hello.rpc_id(1, {
		"protocol": PROTOCOL_VERSION,
		"game_version": _game_version(),
		"profile_id": RunSession.profile.profile_id,
		"name": RunSession.profile.display_name,
	})

@rpc("authority", "call_remote", "reliable")
func _welcome(slot:int, roster:Array)->void:
	if state != State.CONNECTING:
		return
	var _local:PlayerState = RunSession.local_player()
	RunSession.players.states.erase(RunSession.players.local_slot)
	_local.slot = slot
	_local.peer_id = local_peer_id()
	RunSession.players.local_slot = slot
	RunSession.players.add(_local)
	_set_state(State.JOINED)
	_roster_update(roster)

@rpc("authority", "call_remote", "reliable")
func _roster_update(roster:Array)->void:
	if state != State.JOINED:
		return
	var _seen:Dictionary = {}
	for _entry:Variant in roster:
		if !(_entry is Dictionary):
			continue
		var _slot:int = int(_entry.get("slot", -1))
		if _slot < 0 || _slot >= MAX_PLAYERS:
			continue
		_seen[_slot] = true
		if _slot == RunSession.players.local_slot:
			continue
		var _state:PlayerState = RunSession.players.get_state(_slot)
		if _state == null:
			_state = PlayerState.create_remote(str(_entry.get("profile_id", "")), _clean_name(str(_entry.get("name", ""))), _slot)
			_state.peer_id = int(_entry.get("peer_id", 0))
			RunSession.players.add(_state)
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local && !_seen.has(_state.slot):
			RunSession.players.remove(_state.slot)
	roster_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rejected(reason:String)->void:
	var _was:State = state
	_close("")
	if _was == State.CONNECTING:
		connection_failed.emit(reason)
	else:
		session_ended.emit(reason)

func _on_connection_failed()->void:
	_close("")
	connection_failed.emit("Couldn't reach the host")

func _on_server_disconnected()->void:
	var _was:State = state
	_close("")
	if _was == State.CONNECTING:
		connection_failed.emit("The host closed the connection")
	else:
		session_ended.emit("The host left")

# --- Both -------------------------------------------------------------------

func leave()->void:
	if state == State.OFFLINE:
		return
	_close("You left")
	session_ended.emit("You left")

func _close(_reason:String)->void:
	if multiplayer.multiplayer_peer != null && !(multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	transport.close()
	_pending_hello.clear()
	share_addresses = []
	# back to a lone local player in slot 0
	var _local:PlayerState = RunSession.local_player()
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local:
			RunSession.players.remove(_state.slot)
	RunSession.players.states.clear()
	_local.slot = 0
	_local.peer_id = 1
	RunSession.players.local_slot = 0
	RunSession.players.states[0] = _local
	_set_state(State.OFFLINE)
	roster_changed.emit()

func _process(delta:float)->void:
	if state == State.CONNECTING:
		_connect_time_left -= delta
		if _connect_time_left <= 0.0:
			_close("")
			connection_failed.emit("Timed out connecting")
	if is_host() && !_pending_hello.is_empty():
		for _peer:int in _pending_hello.keys():
			_pending_hello[_peer] -= delta
			if _pending_hello[_peer] <= 0.0:
				_pending_hello.erase(_peer)
				_drop_peer(_peer)

func _set_state(value:State)->void:
	if state == value:
		return
	state = value
	state_changed.emit()

func _game_version()->String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))

static func _clean_name(text:String)->String:
	var _name:String = text.strip_edges().replace("\n", " ").left(MAX_NAME_LENGTH)
	return _name if !_name.is_empty() else "Player"

func _exit_tree()->void:
	if _share_thread != null:
		_share_thread.wait_to_finish()
