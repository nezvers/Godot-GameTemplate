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
const HOME_BASE_PATH:String = "res://game/resources/home_base_resource.tres"
const HOME_SCENE:String = "res://game/scenes/room_H00.tscn"
const VICTORY_SCENE:String = "res://game/scenes/victory.tscn"
const GAME_OVER_SCENE:String = TD + "scenes/ui/screens/game_over.tscn"
## Seconds the "host left" note stays up.
const NOTE_TIME:float = 4.0
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
## A ghost's position reports (one way, to the host only).
const GHOST_INTERVAL:float = 0.1
var _ghost_send_left:float
var _inventory_dirty:bool
## Guest back from a ghost: on arriving in this room it waits at the door.
var _returning_to:String
## Guest leaving by its own choice (GuestLeaveMenu): don't treat it as a lost host.
var leaving_by_choice:bool
## Guest: the host is on its victory / game over screen and we weren't in its
## run: we wait where we are for its next room (end_screen_wait()).
var _held_back:String
## Guest: the host room we went to with a gun lent from our own home base.
var _lent_to:String
var _note_layer:CanvasLayer

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
	RunSession.local_player().inventory.updated.connect(func ()->void: _inventory_dirty = true)
	var _revive:ReviveAssist = ReviveAssist.new()
	_revive.name = "ReviveAssist"
	add_child(_revive)

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
	_dress_local()
	if net().is_ghost():
		_was_guest = false
		if !puppets.is_empty():
			_clear_puppets()
		_ghost_tick(delta)
		return
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
		_settle_loadout()
		_guest_run_data_tick(delta)
		_check_return_arrival()
	for _slot:int in puppets.keys():
		if !is_instance_valid(puppets[_slot]) || !puppets[_slot].is_inside_tree():
			puppets.erase(_slot)

## The local body wears its slot's skin (host plumber, guests electrician).
var _dressed_body:Node
var _dressed_slot:int = -1

func _dress_local()->void:
	var _body:Node2D = local_body()
	var _slot:int = RunSession.players.local_slot
	var _local:PlayerState = RunSession.local_player()
	if _body != null && !_local.downed && !_local.waiting:
		# a ghost-tier guest sees itself faint in the host's home base too
		var _visual:Node2D = _body.get_node_or_null("Body")
		if _visual != null:
			_visual.modulate.a = GuestTier.alpha(_local)
	if _body == null || (_body == _dressed_body && _slot == _dressed_slot):
		return
	_dressed_body = _body
	_dressed_slot = _slot
	PlayerSkin.apply(_body, _slot)

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
		if _state.is_local:
			continue
		if _state.ghost:
			_ghost_status.rpc_id(_state.peer_id, party_room)
		else:
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
	_host_room_before = _host_room
	_host_room = path
	_try_follow()

## Loads the host's room once no transition is running.
func _try_follow()->void:
	var _home:HomeBase = current_home()
	# (our own home base has the same path as the host's: load the host's one)
	if current_room() == _pending_room && (_home == null || _home.guest_mode):
		_pending_room = ""
		return
	if transition_bool.value:
		return
	var _path:String = _pending_room
	var _entry:String = _pending_entry
	_pending_room = ""
	# the host's victory / game over screen ends a run we weren't part of: stay
	# here, its next room (home base or a mission) takes us along
	if !can_rejoin(_path) && !_in_host_game():
		if _held_back != _path:
			show_note("The host is on its %s screen - you'll join its next room" % ("victory" if _path == VICTORY_SCENE else "end"))
		_held_back = _path
		return
	_held_back = ""
	if _home != null && _home.guest_mode:
		# leaving the host's home base for its mission: the weapon in hand goes along
		_home.depart()
	elif _home != null && _path != HOME_SCENE:
		# from our own home base into the host's mission: one gun goes along
		# (HomeBase.lend_to_host), the rest stays in our stash
		_home.lend_to_host()
		_lent_to = _path
	var _door_arrival:bool = !_entry.is_empty() && local_body() != null && scene_transition.change_scene.get_connections().size() > 0
	if _door_arrival:
		# the room's PlayerSpawner carries our player to the same door
		scene_transition.set_next_scene(_path, _entry)
	else:
		scene_transition.next_scene_path = ""
		scene_transition.entry_tag = ""
		Transition.change_scene(_path)

## Guest, arrived with a gun lent from our own home base: a start room's
## FreshStart handed it over as the loadout; anywhere else it came along in
## hand and the loadout mustn't wait for the next start room (a second copy).
func _settle_loadout()->void:
	if _lent_to.is_empty() || current_room() != _lent_to || local_body() == null || transition_bool.value:
		return
	_lent_to = ""
	var _home_resource:HomeBaseResource = load(HOME_BASE_PATH)
	if _home_resource.loadout.is_empty():
		return
	var _inventory:ItemCollectionResource = RunSession.local_player().inventory
	if _inventory.list.is_empty():
		var _item:ItemResource = HomeBaseResource.find_item(load(DATABASE_PATH), _home_resource.loadout)
		if _item != null:
			_inventory.append(_item)
	_home_resource.loadout = ""
	_home_resource.save_resource()

## Guest: we're already in the host's game (in one of its rooms, or its home
## base), not just joined from our own home.
func _in_host_game()->bool:
	var _home:HomeBase = current_home()
	if _home != null:
		return _home.guest_mode
	return can_rejoin(current_room()) && current_room() == _host_room_before

## The host's room before its latest _follow_room.
var _host_room_before:String

## Guest: the host is on an end screen we didn't follow it onto ("" if not).
func end_screen_wait()->String:
	return _held_back if net().is_guest() else ""

## The home base node of the room we're in, if any.
func current_home()->HomeBase:
	var _scene:Node = get_tree().current_scene
	return _scene.get_node_or_null("HomeBase") as HomeBase if _scene != null else null

static func _valid_scene(path:String)->bool:
	var _known:bool = path.begins_with("res://game/scenes/") || path.begins_with("res://addons/top_down/scenes/ui/screens/")
	return _known && path.length() < MAX_PATH && path.ends_with(".tscn") && !path.contains("..") && ResourceLoader.exists(path)

func _on_session_ended(_reason:String)->void:
	_pending_room = ""
	_held_back = ""
	_lent_to = ""
	_host_room = ""
	_host_room_before = ""
	_pending_restore = null
	_clear_puppets()
	if _was_guest:
		_was_guest = false
		on_host_lost()

## Guest whose host went away: back home, unless already there or in a menu.
func on_host_lost()->void:
	if leaving_by_choice:
		leaving_by_choice = false
		return
	var _room:String = current_room()
	var _home:HomeBase = current_home()
	if _home != null && _home.guest_mode:
		# standing in the host's home base: back to ours, empty-handed
		_lost_host_go_home()
		return
	if _room == VICTORY_SCENE || _room == GAME_OVER_SCENE:
		# on the host's end screen (it went to the main menu): no host to follow
		_lost_host_go_home()
		return
	if _room == HOME_SCENE || _room == TITLE_SCENE || local_body() == null:
		return
	_lost_host_go_home()

func _lost_host_go_home()->void:
	host_lost.emit()
	show_note("The host left the game")
	Transition.change_scene(HOME_SCENE)

## A line of text at the top of the screen for a few seconds; it outlives
## scene changes (it hangs under the Net autoload).
func show_note(text:String)->void:
	if _note_layer != null && is_instance_valid(_note_layer):
		_note_layer.queue_free()
	_note_layer = CanvasLayer.new()
	_note_layer.name = "NoteLayer"
	_note_layer.layer = 6
	add_child(_note_layer)
	var _label:Label = Label.new()
	_label.name = "Note"
	_label.text = text
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.offset_left = -140
	_label.offset_right = 140
	_label.offset_top = 24
	_label.offset_bottom = 36
	_note_layer.add_child(_label)
	var _layer:CanvasLayer = _note_layer
	get_tree().create_timer(NOTE_TIME, true).timeout.connect(func ()->void:
		if is_instance_valid(_layer):
			_layer.queue_free()
	)

# --- Player updates -------------------------------------------------------------

func _send_local()->void:
	var _local:PlayerState = RunSession.local_player()
	if _local.hidden:
		return
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
	_player_update.rpc([_room, _pos, _axis, _aim, _local.active_weapon_name(), _local.health.hp, _local.health.max_hp, _local.downed, _local.revive_progress, _local.waiting, _local.reviving, NetInterp.now()])

## Where this machine's body is and how it moves (shared by ghost reports).
func _local_motion()->Array:
	var _body:Node2D = local_body()
	if _body == null:
		return ["", Vector2.ZERO, Vector2.ZERO, Vector2.RIGHT]
	var _resources:ResourceNode = _body.get_node_or_null("ResourceNode")
	var _input:InputResource = _resources.get_resource("input") if _resources != null else null
	return [current_room(), _body.global_position, _input.axis if _input != null else Vector2.ZERO, _input.aim_direction if _input != null else Vector2.RIGHT]

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _player_update(data:Array)->void:
	var _state:PlayerState = _sender_state()
	if _state == null || _state.ghost || !_valid_update(data):
		return
	apply_update(_state, data)

func _sender_state()->PlayerState:
	var _peer:int = multiplayer.get_remote_sender_id()
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local && _state.peer_id == _peer:
			return _state
	return null

static func _valid_update(data:Array)->bool:
	if data.size() != 12:
		return false
	var _types:Array = [TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2, TYPE_VECTOR2, TYPE_STRING, TYPE_FLOAT, TYPE_FLOAT, TYPE_BOOL, TYPE_FLOAT, TYPE_BOOL, TYPE_BOOL, TYPE_FLOAT]
	for _i:int in _types.size():
		if typeof(data[_i]) != _types[_i]:
			return false
	var _pos:Vector2 = data[1]
	return (data[0] as String).length() < MAX_PATH && (data[4] as String).length() < MAX_WEAPON_NAME \
		&& _pos.is_finite() && (data[2] as Vector2).is_finite() && (data[3] as Vector2).is_finite() \
		&& is_finite(data[5]) && is_finite(data[11]) && is_finite(data[6]) && float(data[6]) > 0.0 && float(data[6]) < 100000.0 && is_finite(data[8])

## Mirrors a teammate's update into its PlayerState and puppet.
func apply_update(state:PlayerState, data:Array)->void:
	var _room:String = data[0]
	var _weapon:String = data[4]
	var _revive:float = clampf(data[8], 0.0, 1.0)
	var _changed:bool = state.room_scene != _room || state.weapon_name != _weapon || state.downed != data[7] || !is_equal_approx(state.revive_progress, _revive) || state.waiting != data[9]
	state.room_scene = _room
	state.revive_progress = _revive
	state.reviving = data[10]
	if state.waiting != data[9]:
		state.waiting = data[9]
		RunSession.players.check_all_downed()
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
	_update_puppet(state, data[1], data[2], data[3], data[11])

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

## The room a teammate shows up in on this machine: its own, or for a ghost the
## home base it walks (seen only in our home base).
static func shown_room(state:PlayerState)->String:
	if state.ghost:
		return state.ghost_room if state.ghost_room == HOME_SCENE else ""
	return state.room_scene

## `sent`: the teammate's clock when it was there (NetInterp plays it back smoothly).
func _update_puppet(state:PlayerState, pos:Vector2, axis:Vector2, aim:Vector2, sent:float)->void:
	var _room:String = shown_room(state)
	var _here:bool = !_room.is_empty() && _room == current_room() && local_body() != null && !transition_bool.value
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
	_driver.push(sent, pos, axis, aim)

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
	reclaim_weapons(state)
	_remove_puppet(state.slot)

## Host: a guest leaving our home base doesn't take our weapons with it; what it
## last said it held is put back on the floor where it stood.
func reclaim_weapons(state:PlayerState)->void:
	if !net().is_host() || state == null || state.is_local || state.guest_run_data == null:
		return
	if current_room() != HOME_SCENE || state.room_scene != HOME_SCENE || current_home() == null:
		return
	var _puppet:Node2D = puppets.get(state.slot)
	var _at:Vector2 = _puppet.global_position if _puppet != null && is_instance_valid(_puppet) else current_home().water_gun_spot.global_position
	var _database:ItemCollectionResource = load(DATABASE_PATH)
	var _i:int = 0
	for _name:String in state.guest_run_data.weapons:
		var _item:ItemResource = HomeBaseResource.find_item(_database, _name)
		if _item != null:
			Net.entities.drop_item(_item, _at + Vector2(6.0 * _i, 0.0))
			_i += 1
	state.guest_run_data.weapons = PackedStringArray()

## Host leaving its home base for a mission: weapons guests here hold beyond the
## one in hand (that one goes along).
func guest_spare_weapons()->PackedStringArray:
	var _names:PackedStringArray = []
	for _state:PlayerState in RunSession.players.all():
		if _state.is_local || _state.ghost || _state.guest_run_data == null || _state.room_scene != HOME_SCENE:
			continue
		var _weapons:PackedStringArray = _state.guest_run_data.weapons
		for _i:int in _weapons.size():
			if _i != clampi(_state.guest_run_data.selected, 0, _weapons.size() - 1):
				_names.append(_weapons[_i])
	return _names

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
	if _inventory_dirty:
		# a weapon picked up or dropped: the host hears of it right away
		_inventory_dirty = false
		_run_data_left = minf(_run_data_left, 0.15)
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
	if _body != null && !RunSession.local_player().hidden && !_body.has_node("Downed"):
		var _downed:Downed = Downed.new()
		_downed.name = "Downed"
		_body.add_child(_downed)

func _local_downed()->Downed:
	var _body:Node2D = local_body()
	return _body.get_node_or_null("Downed") as Downed if _body != null else null

## Host: nobody is left standing.
func _on_all_downed()->void:
	if !net().is_host() || (RunSession.players.count_active() < 2 && !net().is_server()):
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
	if net().is_server():
		net().server.on_party_wiped()

# --- Ghosts ---------------------------------------------------------------------

func host_room()->String:
	return _host_room

## Guest -> host: we're off home; mid-run (`parked`) our run state goes along so
## the host can hand it back on return.
func send_going_ghost(parked:bool)->void:
	_was_guest = false
	_pending_room = ""
	_pending_restore = null
	_returning_to = ""
	_going_ghost.rpc_id(1, parked, RunSession.local_player().capture().to_dict() if parked else {})

@rpc("any_peer", "call_remote", "reliable")
func _going_ghost(parked:bool, data:Dictionary)->void:
	if !net().is_host():
		return
	var _state:PlayerState = _sender_state()
	if _state == null || _state.ghost:
		return
	reclaim_weapons(_state)
	var _parsed:PlayerRunData = PlayerRunData.from_dict(data) if parked else null
	_state.ghost = true
	_state.waiting = false
	_state.ghost_room = ""
	_state.room_scene = ""
	_state.parked = parked && _parsed != null && RunSession.active
	_state.guest_run_data = _parsed if _state.parked else null
	_state.downed = false
	_remove_puppet(_state.slot)
	_ghost_status.rpc_id(_state.peer_id, party_room)
	_state.net_updated.emit()
	net().roster_changed.emit()
	RunSession.players.check_all_downed()

## Ghost: where we are in our own world, ten times a second.
func _ghost_tick(delta:float)->void:
	_ghost_send_left -= delta
	if _ghost_send_left > 0.0:
		return
	_ghost_send_left = GHOST_INTERVAL
	_ghost_update.rpc_id(1, _local_motion() + [NetInterp.now()])

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _ghost_update(data:Array)->void:
	if !net().is_host():
		return
	var _state:PlayerState = _sender_state()
	if _state == null || !_state.ghost || data.size() != 5 || typeof(data[0]) != TYPE_STRING || (data[0] as String).length() > MAX_PATH:
		return
	if typeof(data[4]) != TYPE_FLOAT || !is_finite(data[4]):
		return
	for _i:int in [1, 2, 3]:
		if typeof(data[_i]) != TYPE_VECTOR2 || !(data[_i] as Vector2).is_finite():
			return
	if _state.ghost_room != data[0]:
		_state.ghost_room = data[0]
		_state.net_updated.emit()
	_update_puppet(_state, data[1], data[2], data[3], data[4])

## Host -> ghost: the room the host is in now.
@rpc("authority", "call_remote", "reliable")
func _ghost_status(room:String)->void:
	if !net().is_ghost() || room.length() > MAX_PATH:
		return
	net().ghost_host_room = room
	net().ghost_status_changed.emit()

## A room the rejoin portal can take us to (not a menu or the victory screen).
static func can_rejoin(room:String)->bool:
	return room.begins_with("res://game/scenes/room_")

## Ghost (now joined again) -> host: put us back in the game.
func request_return()->void:
	_was_guest = true
	_returning_to = "?"
	_ghost_return.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _ghost_return()->void:
	if !net().is_host():
		return
	var _state:PlayerState = _sender_state()
	if _state == null || !_state.ghost:
		return
	_state.ghost = false
	_state.ghost_room = ""
	_remove_puppet(_state.slot)
	net()._broadcast_roster()
	_follow_room.rpc_id(_state.peer_id, party_room, party_entry)
	if _state.parked && _state.guest_run_data != null:
		_restore_run.rpc_id(_state.peer_id, _state.guest_run_data.to_dict())
	_state.parked = false
	_state.net_updated.emit()
	net().roster_changed.emit()

## Guest, just welcomed into a session (Net._welcome): a fight may be on in the
## host's room, so we arrive waiting at the door like a ghost coming back
## (WaitingAtDoor lets go at once when there's none). Our run state goes to the
## host right away, not RUN_DATA_INTERVAL later, so its checkpoint has all of it.
func on_joined()->void:
	_was_guest = true
	_returning_to = "?"
	_run_data_left = 0.0
	_held_back = ""
	_host_room = ""
	_host_room_before = ""

## Guest just back from a ghost: once in the host's room, wait at the door until
## no fight is on (WaitingAtDoor lets go by itself when the walls drop).
func _check_return_arrival()->void:
	if _returning_to.is_empty():
		return
	if _returning_to == "?":
		_returning_to = _host_room if !_host_room.is_empty() else "?"
		return
	if !_host_room.is_empty() && _host_room != _returning_to:
		# the host moved on before we got there (or we were held back from its
		# end screen): wait at the door of wherever it is now
		_returning_to = _host_room
	if !can_rejoin(_returning_to):
		return
	if current_room() != _returning_to || local_body() == null || transition_bool.value:
		return
	_returning_to = ""
	if current_room() == HOME_SCENE:
		return
	var _body:Node2D = local_body()
	if !_body.has_node("WaitingAtDoor"):
		var _wait:WaitingAtDoor = WaitingAtDoor.new()
		_wait.name = "WaitingAtDoor"
		_body.add_child(_wait)

## Host, victory: ghosts who left mid-run still get the weapons they carried.
func send_ghost_rewards()->void:
	if !net().is_host():
		return
	for _state:PlayerState in RunSession.players.all():
		if _state.ghost && _state.parked && _state.guest_run_data != null:
			_ghost_rewards.rpc_id(_state.peer_id, _state.guest_run_data.weapons)

@rpc("authority", "call_remote", "reliable")
func _ghost_rewards(weapons:PackedStringArray)->void:
	if !net().is_ghost() || weapons.size() > PlayerRunData.MAX_WEAPONS:
		return
	# a ghost-tier guest keeps nothing from the host's run (GuestTier)
	if !RunSession.local_player().electrician:
		return
	var _database:ItemCollectionResource = load(DATABASE_PATH)
	var _carried:ItemCollectionResource = ItemCollectionResource.new()
	for _name:String in weapons:
		var _item:ItemResource = HomeBaseResource.find_item(_database, _name)
		if _item != null:
			_carried.list.append(_item)
	if _carried.list.is_empty():
		return
	# standing in our home base: they're dropped at our feet (its stash is live)
	var _home:HomeBase = get_tree().current_scene.get_node_or_null("HomeBase") as HomeBase if get_tree().current_scene != null else null
	if _home != null:
		_home.receive_weapons(_carried.list)
	else:
		(load(HOME_BASE_PATH) as HomeBaseResource).stash_weapons(_carried)

## The run is over (RunSession.end_run): parked run states go with it.
func on_run_ended()->void:
	for _state:PlayerState in RunSession.players.all():
		if _state.parked:
			_state.parked = false
			_state.guest_run_data = null

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
