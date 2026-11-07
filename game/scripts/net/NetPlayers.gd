## Keeps every machine showing every player: lives under the Net autoload as
## /root/Net/Players, so its RPC path is the same on all peers.
##
## - Each machine sends its own player ~20 times a second (unreliable): room,
##   position, move/aim direction, weapon in hand, hp. Guests' updates reach the
##   other guests through the host (server relay).
## - A teammate in the same room as this machine's player gets a RemotePlayer
##   puppet; one in another room only shows up in the party panel.
## - The host decides where the party is: when its scene changes it tells the
##   guests (_follow_room) and they load the same room, arriving through the same
##   door. Guests' own doors and exits don't fire.
## - The host going back to the title ends the session; a guest whose host is
##   gone mid-run goes back to its own home base.
class_name NetPlayers
extends Node

const SEND_INTERVAL:float = 0.05
const TD:String = "res://addons/top_down/"
const PLAYER_REFERENCE_PATH:String = TD + "resources/ReferenceNodeResources/player_reference.tres"
const PLAYER_INSTANCE_PATH:String = TD + "resources/InstanceResources/actors/player_instance_resource.tres"
const TRANSITION_PATH:String = TD + "resources/global_resources/scene_transition_resource.tres"
const TRANSITION_BOOL_PATH:String = TD + "resources/global_resources/transition_bool_resource.tres"
const PAUSE_PATH:String = TD + "resources/global_resources/pause_resource.tres"
const DATABASE_PATH:String = TD + "resources/ItemCollectionResource/weapon_database.tres"
const TITLE_SCENE:String = "res://game/scenes/title.tscn"
const HOME_SCENE:String = "res://game/scenes/room_H00.tscn"
const MAX_WEAPON_NAME:int = 48
const MAX_PATH:int = 160

## Guest: the host left while this machine was in one of its rooms.
signal host_lost

var player_reference:ReferenceNodeResource
var scene_transition:SceneTransitionResource
var transition_bool:BoolResource
var pause_resource:BoolResource

## slot -> RemotePlayer puppet node (the player body)
var puppets:Dictionary = {}
## Host: the room the party is in, as last sent to the guests.
var party_room:String
var party_entry:String
## Guest: where the host wants us, until we got there.
var _pending_room:String
var _pending_entry:String
var _send_left:float
var _scene:Node
## This machine was a guest the last time it was online.
var _was_guest:bool
## Guest: the room the host last sent us to, and our saved state from the
## host's co-op checkpoint, applied once we're there.
var _host_room:String
var _pending_restore:PlayerRunData
var _run_data_left:float
## Seconds between a guest's run-state reports to the host (for its checkpoint).
const RUN_DATA_INTERVAL:float = 2.0

func _ready()->void:
	player_reference = load(PLAYER_REFERENCE_PATH)
	scene_transition = load(TRANSITION_PATH)
	transition_bool = load(TRANSITION_BOOL_PATH)
	pause_resource = load(PAUSE_PATH)
	pause_resource.updated.connect(_on_pause_changed)
	var _net:Node = get_parent()
	_net.roster_changed.connect(_on_roster_changed)
	_net.session_ended.connect(_on_session_ended)
	RunSession.players.player_removed.connect(_on_player_removed)
	RunSession.players.all_downed.connect(_on_all_downed)

func net()->Node:
	return get_parent()

func current_room()->String:
	var _scene_now:Node = get_tree().current_scene
	return _scene_now.scene_file_path if _scene_now != null else ""

## The local player node, while it is placed in a room.
func local_body()->Node2D:
	var _node:Object = player_reference.node
	if _node == null || !is_instance_valid(_node) || !(_node is Node2D) || !(_node as Node2D).is_inside_tree():
		return null
	return _node as Node2D

func _physics_process(delta:float)->void:
	if !net().is_online():
		if !puppets.is_empty():
			_clear_puppets()
		return
	_was_guest = net().is_guest()
	_ensure_downed()
	_watch_scene()
	if net().is_guest() && !_pending_room.is_empty():
		_try_follow()
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left = SEND_INTERVAL
		_send_local()
	if net().is_guest():
		_guest_run_data_tick(delta)
	for _slot:int in puppets.keys():
		if !is_instance_valid(puppets[_slot]) || !puppets[_slot].is_inside_tree():
			puppets.erase(_slot)

# --- Rooms --------------------------------------------------------------------

func _watch_scene()->void:
	var _now:Node = get_tree().current_scene
	if _now == _scene:
		return
	_scene = _now
	if _now == null || !net().is_host():
		return
	if _now.scene_file_path == TITLE_SCENE:
		net().leave()
		return
	party_room = _now.scene_file_path
	party_entry = scene_transition.entry_tag
	_broadcast_room()

func _broadcast_room()->void:
	if party_room.is_empty():
		return
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local:
			_follow_room.rpc_id(_state.peer_id, party_room, party_entry)

func _on_roster_changed()->void:
	# a guest that just joined learns where the party is
	if net().is_host():
		_broadcast_room()
		_return_saved_guests()
	for _slot:int in puppets.keys():
		if RunSession.players.get_state(_slot) == null:
			_remove_puppet(_slot)

@rpc("authority", "call_remote", "reliable")
func _follow_room(path:String, entry_tag:String)->void:
	if !net().is_guest() || !_valid_scene(path) || entry_tag.length() > MAX_PATH:
		return
	_pending_room = path
	_pending_entry = entry_tag
	_host_room = path
	_try_follow()

## Loads the host's room once no transition is running.
func _try_follow()->void:
	if current_room() == _pending_room:
		_pending_room = ""
		return
	if transition_bool.value:
		return
	var _path:String = _pending_room
	var _entry:String = _pending_entry
	_pending_room = ""
	# leaving our home base for the host's mission: our one gun goes along
	var _home:Node = get_tree().current_scene.get_node_or_null("HomeBase") if get_tree().current_scene != null else null
	if _home != null && _home.has_method("depart"):
		_home.depart()
	var _door_arrival:bool = !_entry.is_empty() && local_body() != null && scene_transition.change_scene.get_connections().size() > 0
	if _door_arrival:
		# the room's PlayerSpawner carries our player to the same door
		scene_transition.set_next_scene(_path, _entry)
	else:
		scene_transition.next_scene_path = ""
		scene_transition.entry_tag = ""
		Transition.change_scene(_path)

static func _valid_scene(path:String)->bool:
	var _known:bool = path.begins_with("res://game/scenes/") || path.begins_with("res://addons/top_down/scenes/ui/screens/")
	return _known && path.length() < MAX_PATH && path.ends_with(".tscn") && !path.contains("..") && ResourceLoader.exists(path)

func _on_session_ended(_reason:String)->void:
	_pending_room = ""
	_pending_restore = null
	_clear_puppets()
	if _was_guest:
		_was_guest = false
		on_host_lost()

## Guest whose host went away: back home, unless already there or in a menu.
func on_host_lost()->void:
	var _room:String = current_room()
	if _room == HOME_SCENE || _room == TITLE_SCENE || local_body() == null:
		return
	host_lost.emit()
	Transition.change_scene(HOME_SCENE)

# --- Player updates -------------------------------------------------------------

func _send_local()->void:
	var _local:PlayerState = RunSession.local_player()
	var _body:Node2D = local_body()
	var _pos:Vector2 = Vector2.ZERO
	var _axis:Vector2 = Vector2.ZERO
	var _aim:Vector2 = Vector2.RIGHT
	var _room:String = ""
	if _body != null:
		_room = current_room()
		_pos = _body.global_position
		var _resources:ResourceNode = _body.get_node_or_null("ResourceNode")
		var _input:InputResource = _resources.get_resource("input") if _resources != null else null
		if _input != null:
			_axis = _input.axis
			_aim = _input.aim_direction
	_player_update.rpc([_room, _pos, _axis, _aim, _local.active_weapon_name(), _local.health.hp, _local.health.max_hp, _local.downed, _local.revive_progress])

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _player_update(data:Array)->void:
	var _state:PlayerState = _sender_state()
	if _state == null || !_valid_update(data):
		return
	apply_update(_state, data)

func _sender_state()->PlayerState:
	var _peer:int = multiplayer.get_remote_sender_id()
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local && _state.peer_id == _peer:
			return _state
	return null

static func _valid_update(data:Array)->bool:
	if data.size() != 9:
		return false
	var _types:Array = [TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2, TYPE_VECTOR2, TYPE_STRING, TYPE_FLOAT, TYPE_FLOAT, TYPE_BOOL, TYPE_FLOAT]
	for _i:int in _types.size():
		if typeof(data[_i]) != _types[_i]:
			return false
	var _pos:Vector2 = data[1]
	return (data[0] as String).length() < MAX_PATH && (data[4] as String).length() < MAX_WEAPON_NAME \
		&& _pos.is_finite() && (data[2] as Vector2).is_finite() && (data[3] as Vector2).is_finite() \
		&& is_finite(data[5]) && is_finite(data[6]) && float(data[6]) > 0.0 && float(data[6]) < 100000.0 && is_finite(data[8])

## Mirrors a teammate's update into its PlayerState and puppet.
func apply_update(state:PlayerState, data:Array)->void:
	var _room:String = data[0]
	var _weapon:String = data[4]
	var _revive:float = clampf(data[8], 0.0, 1.0)
	var _changed:bool = state.room_scene != _room || state.weapon_name != _weapon || state.downed != data[7] || !is_equal_approx(state.revive_progress, _revive)
	state.room_scene = _room
	state.revive_progress = _revive
	# through the registry: the host ends the run once everyone is down
	RunSession.players.set_downed(state.slot, data[7])
	if state.weapon_name != _weapon || (state.inventory.list.is_empty() != _weapon.is_empty()):
		state.weapon_name = _weapon
		_set_weapon(state, _weapon)
	var _max:float = data[6]
	var _hp:float = clampf(data[5], 0.0, _max)
	if !is_equal_approx(state.health.max_hp, _max):
		state.health.max_hp = _max
		state.health.max_hp_changed.emit()
		_changed = true
	if !is_equal_approx(state.health.hp, _hp):
		state.health.hp = _hp
		state.health.hp_changed.emit()
		_changed = true
	if _changed:
		state.net_updated.emit()
	_update_puppet(state, data[1], data[2], data[3])

## Only the weapon in hand travels: the puppet holds just that one.
func _set_weapon(state:PlayerState, weapon:String)->void:
	var _list:Array[ItemResource] = []
	if !weapon.is_empty():
		var _item:ItemResource = HomeBaseResource.find_item(load(DATABASE_PATH), weapon)
		if _item != null:
			_list.append(_item)
	state.inventory.set_list(_list)
	state.inventory.set_selected(0)

# --- Puppets --------------------------------------------------------------------

func _update_puppet(state:PlayerState, pos:Vector2, axis:Vector2, aim:Vector2)->void:
	var _here:bool = !state.room_scene.is_empty() && state.room_scene == current_room() && local_body() != null && !transition_bool.value
	var _puppet:Node2D = puppets.get(state.slot)
	if _puppet != null && !is_instance_valid(_puppet):
		_puppet = null
		puppets.erase(state.slot)
	if !_here:
		if _puppet != null:
			_remove_puppet(state.slot)
		return
	if _puppet == null:
		var _parent:Node = (load(PLAYER_INSTANCE_PATH) as InstanceResource).parent_reference_resource.node
		if _parent == null || !_parent.is_inside_tree():
			return
		_puppet = RemotePlayer.create(state, pos)
		_parent.add_child(_puppet)
		puppets[state.slot] = _puppet
		RunSession.players.set_node(state.slot, _puppet)
	var _driver:RemotePlayer = _puppet.get_node("RemotePlayer")
	_driver.push(pos, axis, aim)

func _remove_puppet(slot:int)->void:
	var _puppet:Node = puppets.get(slot)
	puppets.erase(slot)
	RunSession.players.nodes.erase(slot)
	if _puppet != null && is_instance_valid(_puppet):
		_puppet.queue_free()

func _clear_puppets()->void:
	for _slot:int in puppets.keys():
		_remove_puppet(_slot)

func _on_player_removed(state:PlayerState)->void:
	_remove_puppet(state.slot)

# --- Co-op checkpoint ------------------------------------------------------------

## Guest: our run state, so the host's checkpoint can hand it back later.
func _guest_run_data_tick(delta:float)->void:
	if _pending_restore != null:
		if local_body() != null && current_room() == _host_room && !transition_bool.value:
			var _local:PlayerState = RunSession.local_player()
			_local.apply(_pending_restore)
			_local.apply_health(_pending_restore)
			_pending_restore = null
		return
	_run_data_left -= delta
	if _run_data_left > 0.0 || local_body() == null:
		return
	_run_data_left = RUN_DATA_INTERVAL
	_guest_run_data.rpc_id(1, RunSession.local_player().capture().to_dict())

@rpc("any_peer", "call_remote", "reliable")
func _guest_run_data(data:Dictionary)->void:
	if !net().is_host():
		return
	var _state:PlayerState = _sender_state()
	var _parsed:PlayerRunData = PlayerRunData.from_dict(data)
	if _state != null && _parsed != null:
		_state.guest_run_data = _parsed

## Host of a continued co-op run: a guest from the save is back, return its state.
func _return_saved_guests()->void:
	for _state:PlayerState in RunSession.players.all():
		var _saved:PlayerRunData = RunSession.waiting_guests.get(_state.profile_id)
		if _state.is_local || _saved == null:
			continue
		RunSession.waiting_guests.erase(_state.profile_id)
		_state.guest_run_data = _saved
		_restore_run.rpc_id(_state.peer_id, _saved.to_dict())

@rpc("authority", "call_remote", "reliable")
func _restore_run(data:Dictionary)->void:
	if !net().is_guest():
		return
	_pending_restore = PlayerRunData.from_dict(data)

# --- Downed --------------------------------------------------------------------

func _ensure_downed()->void:
	var _body:Node2D = local_body()
	if _body != null && !_body.has_node("Downed"):
		var _downed:Downed = Downed.new()
		_downed.name = "Downed"
		_body.add_child(_downed)

func _local_downed()->Downed:
	var _body:Node2D = local_body()
	return _body.get_node_or_null("Downed") as Downed if _body != null else null

## Host: nobody is left standing.
func _on_all_downed()->void:
	if !net().is_host() || RunSession.players.count() < 2:
		return
	_party_wiped.rpc()
	_party_wiped_here()

@rpc("authority", "call_remote", "reliable")
func _party_wiped()->void:
	if net().is_guest():
		_party_wiped_here()

func _party_wiped_here()->void:
	for _state:PlayerState in RunSession.players.all():
		_state.downed = false
	var _downed:Downed = _local_downed()
	if _downed != null:
		_downed.wipe()

# --- Pause ----------------------------------------------------------------------

## Online the world keeps running under the pause menu (the room's
## PauseProcessingComponent leaves it alone), only our player stops.
func _on_pause_changed()->void:
	var _body:Node2D = local_body()
	var _input:Node = _body.get_node_or_null("PlayerInput") if _body != null else null
	if _input == null:
		return
	if !pause_resource.value:
		_input.set_enabled(true)
		return
	if !net().is_online():
		return
	_input.set_enabled(false)
	var _move:InputResource = (_body.get_node("ResourceNode") as ResourceNode).get_resource("input")
	_move.set_axis(Vector2.ZERO)
	_move.set_action(false)
