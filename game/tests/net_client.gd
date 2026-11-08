## Helper for net_loopback_check: a second headless game that joins the host.
## Args after "--": <address> <mode>
##   ok        join normally, report the slot, wait to be kicked
##   badver    send a hello with a wrong protocol, expect a rejection
##   world     (coop_world_check) load the home base, join, pick up a shotgun,
##             follow the host and report rooms, teammates and puppets
## Prints "NETCLIENT <event> <detail>" lines for the host test to read.
extends Node

var _mode:String
var _saved_names:Dictionary = {}
var _report_left:float
var _armed:bool
var _finishing:bool
## world mode: harmless shot copies made here, and enemy copies already scheduled for hits
var _cosmetic_shots:int
var _hit_scheduled:Dictionary = {}
var _fire_left:float
var _ground:bool
var _grind_wait:float
var _pickup_sounds:int

func _ready()->void:
	var _args:PackedStringArray = OS.get_cmdline_user_args()
	var _address:String = _args[0] if _args.size() > 0 else "127.0.0.1"
	_mode = _args[1] if _args.size() > 1 else "ok"
	# a separate profile so the host sees a different player ("sameprofile" keeps
	# the shared one, like a second game started from the same project)
	# ("localguest" is a second copy of the host's very install: a blank guest)
	var _shared_profile:bool = _mode == "sameprofile" || _mode == "localguest"
	if _mode == "sameprofile":
		_mode = "ok"
	if _mode != "localguest":
		# stands in for another computer: not a second copy of the host's install
		GuestSandbox.install_override = "netclient_%d" % OS.get_process_id()
	if _mode == "localguest":
		_mode = "ok"
	if !_shared_profile:
		RunSession.profile.profile_id = "client_%s_%d" % [_mode, OS.get_process_id()]
		RunSession.profile.display_name = "Client " + _mode
		RunSession.local_player().profile_id = RunSession.profile.profile_id
	if _mode == "world":
		_start_world(_address)
		return
	if _mode == "home":
		_start_home(_address)
		return
	if _mode == "ghost":
		_start_ghost(_address)
		return
	Net.connection_failed.connect(func (reason:String)->void: _report("failed", reason); _quit())
	Net.session_ended.connect(func (reason:String)->void: _report("ended", reason); _quit())
	Net.roster_changed.connect(func ()->void:
		if Net.is_guest():
			_report("roster", str(RunSession.players.count())))
	Net.state_changed.connect(func ()->void:
		if Net.is_guest():
			_report("joined", str(RunSession.players.local_slot))
			_report_sandbox())
	if _mode == "badver":
		Net.multiplayer.connected_to_server.disconnect(Net._on_connected_to_server)
		Net.multiplayer.connected_to_server.connect(func ()->void:
			Net._hello.rpc_id(1, {"protocol": -5, "game_version": "x", "profile_id": RunSession.profile.profile_id, "name": "bad"}))
	var _err:Error = Net.join(_address)
	_report("join", str(_err))
	get_tree().create_timer(20.0).timeout.connect(func ()->void: _report("timeout", ""); _quit())

## coop_home_check: a guest in the host's home base, as a ghost then as an
## electrician. Each step waits for what the host set up; the host checks its side.
func _start_home(address:String)->void:
	for _path:String in ["res://game/resources/home_base_resource.tres", "res://game/resources/campaign_resource.tres"]:
		var _resource:SaveableResource = load(_path)
		_saved_names[_resource] = _resource.resource_name
		_resource.resource_name += "_netclient"
		_resource.delete_resource()
		_resource.reset_resource()
	var _home_base:HomeBaseResource = load("res://game/resources/home_base_resource.tres")
	# our own stash: a gun that must stay at home
	_home_base.stash_inventory = PackedStringArray(["Gun"])
	Transition.instant = true
	get_tree().current_scene = null
	get_tree().create_timer(90.0).timeout.connect(func ()->void: _report("timeout", ""); _finish())
	Transition.change_scene("res://game/scenes/room_H00.tscn")
	await _until(func ()->bool: return Net.players.local_body() != null)
	_report("own_home", "%s held=%s" % [_home().guest_mode, _held()])

	# --- 1st visit, as a ghost
	_report("join", str(Net.join(address)))
	await _until(func ()->bool: return Net.is_guest() && _home() != null && _home().guest_mode && Net.players.local_body() != null)
	await _frames(20)
	_report("host_home", "guest_mode=%s held=%s electrician=%s keeps_loot=%s" % [_home().guest_mode, _held(), RunSession.local_player().electrician, GuestTier.keeps_loot()])
	await _until(func ()->bool: return _floor_item("Shotgun") != null)
	_report("alpha", "%.2f" % (Net.players.local_body().get_node("Body") as Node2D).modulate.a)
	var _crystals:ScoreResource = load("res://addons/top_down/resources/global_resources/boss_crystal_resource.tres")
	var _crystals_before:int = _crystals.value
	_crystals.add(3)
	_report("crystals_in_session", str(_crystals.value - _crystals_before))
	# pick the host's shotgun up
	Net.players.local_body().global_position = (_floor_item("Shotgun") as Node2D).global_position
	await _until(func ()->bool: return _held().contains("Shotgun"))
	_report("picked", _held())
	# the lanes: row 1 and column 1 on, then write
	var _grid:PistonGrid = _find(get_tree().current_scene, func (n:Node)->bool: return n is PistonGrid) as PistonGrid
	_grid.row_levers[6].try_use()
	await get_tree().create_timer(0.4).timeout
	_grid.col_levers[6].try_use()
	await _until(func ()->bool: return _grid.row_select[6] == 1 && _grid.col_select[6] == 1)
	_report("lanes", "%d %d" % [_grid.row_select[6], _grid.col_select[6]])
	var _was_raised:bool = _grid.piston(Vector2i(6, 6)).is_raised()
	var _write:WriteButton = _find(get_tree().current_scene, func (n:Node)->bool: return n is WriteButton) as WriteButton
	_write.try_use()
	await _until(func ()->bool: return _grid.piston(Vector2i(6, 6)).is_raised() != _was_raised && !_grid.writing)
	_report("written", "%s->%s" % [_was_raised, _grid.piston(Vector2i(6, 6)).is_raised()])
	await get_tree().create_timer(0.6).timeout
	# leave: back to our own home base, the shotgun stays with the host
	Net.leave()
	await _until(func ()->bool: return !Net.is_online() && _home() != null && !_home().guest_mode && Net.players.local_body() != null)
	await _frames(10)
	_report("back_home", "held=%s crystals=%d" % [_held(), _crystals.value - _crystals_before])

	# --- 2nd visit, as an electrician (printed shell)
	var _meta:MetaUpgradeResource = load("res://game/resources/meta_upgrade_resource.tres")
	var _owned_before:PackedStringArray = _meta.owned.duplicate()
	_meta.owned.append("shell_printer")
	_home_base.electrician_shell = true
	_report("join", str(Net.join(address)))
	await _until(func ()->bool: return Net.is_guest() && _home() != null && _home().guest_mode && Net.players.local_body() != null)
	await _frames(20)
	_report("electrician", "%s keeps_loot=%s alpha=%.2f" % [RunSession.local_player().electrician, GuestTier.keeps_loot(), (Net.players.local_body().get_node("Body") as Node2D).modulate.a])
	_meta.owned = _owned_before
	await _until(func ()->bool: return !Net.is_online())
	_report("ended", "")
	_finish()

## coop_ghost_check: victory -> home with "I will return" -> rejoin through the
## portal into a fight -> wait at the door -> home again mid-run -> back, state
## restored -> walls drop.
func _start_ghost(address:String)->void:
	for _path:String in ["res://game/resources/home_base_resource.tres", "res://game/resources/campaign_resource.tres"]:
		var _resource:SaveableResource = load(_path)
		_saved_names[_resource] = _resource.resource_name
		_resource.resource_name += "_netclient"
		_resource.delete_resource()
		_resource.reset_resource()
	Transition.instant = true
	get_tree().current_scene = null
	get_tree().create_timer(120.0).timeout.connect(func ()->void: _report("timeout", ""); _finish())
	Transition.change_scene("res://game/scenes/room_H00.tscn")
	await _until(func ()->bool: return Net.players.local_body() != null)
	_report("join", str(Net.join(address)))
	await _until(func ()->bool: return Net.is_guest() && _home() != null && _home().guest_mode)
	_report("joined", "")
	# the host goes to its victory screen: we get the guest menu there
	# (the victory animation holds at its pause marker for a click: give it one)
	await _until(func ()->bool:
		_resume_overlays()
		return _victory_menu() != null, 40.0)
	_report("menu", "%s" % (_victory_menu() != null))
	_victory_menu().go_home(true)
	await _until(func ()->bool: return Net.is_ghost() && _home() != null && !_home().guest_mode && Net.players.local_body() != null)
	await _frames(10)
	var _portal:RejoinPortal = _find(get_tree().current_scene, func (n:Node)->bool: return n is RejoinPortal) as RejoinPortal
	_report("away", "state=%d portal=%s" % [Net.state, _portal != null])
	# walk about at home: the host sees it
	var _body:Node2D = Net.players.local_body()
	for _i:int in 10:
		_body.global_position += Vector2(3, 0)
		await get_tree().create_timer(0.1).timeout
	_report("walked", str(_body.global_position))
	# the host goes on a mission: the portal opens onto it
	await _until(func ()->bool: return Net.ghost_host_room.ends_with("room_N00.tscn") && _portal != null && _portal.is_open(), 30.0)
	_report("portal", _portal.label.text if _portal != null else "-")
	_portal._try_rejoin()
	await _until(func ()->bool: return Net.is_guest() && _current().ends_with("room_N00.tscn") && Net.players.local_body() != null && Net.players.local_body().has_node("WaitingAtDoor"), 20.0)
	var _waiting:WaitingAtDoor = Net.players.local_body().get_node_or_null("WaitingAtDoor") as WaitingAtDoor
	_report("arrived", "waiting=%s" % [_waiting != null && RunSession.local_player().waiting])
	await _frames(5)
	if _waiting != null:
		var _anchor:Vector2 = _waiting.anchor
		Net.players.local_body().global_position = _anchor + Vector2(200, 0)
		await _frames(2)
		_report("leash", "%.1f" % Net.players.local_body().global_position.distance_to(_anchor))
	# home again mid-run, carrying a shotgun
	var _inventory:ItemCollectionResource = RunSession.local_player().inventory
	_inventory.append(HomeBaseResource.find_item(load("res://addons/top_down/resources/ItemCollectionResource/weapon_database.tres"), "Shotgun"))
	await _frames(2)
	GuestLeaveMenu.open(_waiting, GuestLeaveMenu.Context.DOOR).go_home(true)
	await _until(func ()->bool: return Net.is_ghost() && _home() != null && Net.players.local_body() != null)
	await _frames(10)
	_portal = _find(get_tree().current_scene, func (n:Node)->bool: return n is RejoinPortal) as RejoinPortal
	_report("parked", "state=%d" % Net.state)
	await _until(func ()->bool: return _portal != null && _portal.is_open(), 20.0)
	_portal._try_rejoin()
	await _until(func ()->bool: return Net.is_guest() && _current().ends_with("room_N00.tscn") && _held().contains("Shotgun"), 20.0)
	_report("restored", _held())
	await _until(func ()->bool: return Net.players.local_body() != null && !Net.players.local_body().has_node("WaitingAtDoor") && !RunSession.local_player().waiting, 30.0)
	_report("released", "")
	await _until(func ()->bool: return !Net.is_online(), 30.0)
	_report("ended", "")
	_finish()

func _resume_overlays()->void:
	var _scene:Node = get_tree().current_scene
	if _scene == null:
		return
	for _node:Node in _scene.find_children("*", "Node2D", true, false):
		if _node.has_method("resume") && _node.has_signal("paused"):
			_node.call("resume")

func _victory_menu()->GuestLeaveMenu:
	var _scene:Node = get_tree().current_scene
	var _screen:Node = _scene.get_node_or_null("VictoryScreen") if _scene != null else null
	return _screen.guest_menu if _screen != null && is_instance_valid(_screen.guest_menu) else null

func _current()->String:
	var _scene:Node = get_tree().current_scene
	return _scene.scene_file_path if _scene != null else ""

func _home()->HomeBase:
	var _scene:Node = get_tree().current_scene
	return _scene.get_node_or_null("HomeBase") as HomeBase if _scene != null else null

func _held()->String:
	var _names:PackedStringArray = []
	for _item:ItemResource in RunSession.local_player().inventory.list:
		if _item != null:
			_names.append(_item.resource_name)
	return ",".join(_names)

## A copy of the host's floor weapon with this name.
func _floor_item(item:String)->Node:
	for _id:int in Net.entities.entities:
		var _node:Node = Net.entities.entities[_id]
		if Net.entities.kinds.get(_id) == NetEntities.Kind.ITEM && is_instance_valid(_node) && (_node as ItemPickup).item_resource.resource_name == item:
			return _node
	return null

func _until(condition:Callable, seconds:float = 15.0)->void:
	var _end:int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < _end && !condition.call():
		await get_tree().process_frame

func _frames(count:int)->void:
	for _i:int in count:
		await get_tree().physics_frame

static func _find(node:Node, test:Callable)->Node:
	if node == null:
		return null
	if test.call(node):
		return node
	for _child:Node in node.get_children():
		var _found:Node = _find(_child, test)
		if _found != null:
			return _found
	return null

## Whether this copy became a blank guest, and what it forgot.
func _report_sandbox()->void:
	var _meta:MetaUpgradeResource = load("res://game/resources/meta_upgrade_resource.tres")
	var _crystals:ScoreResource = load("res://addons/top_down/resources/global_resources/boss_crystal_resource.tres")
	_report("sandbox", "%s %s meta=%d crystals=%d" % [GuestSandbox.active(), RunSession.local_player().profile_id, _meta.owned.size() if "owned" in _meta else -1, _crystals.value])

## Plays like a real guest: own home base first, then joins from there.
func _start_world(address:String)->void:
	# our home base saves while we're in it: keep the user's file out of it
	for _path:String in ["res://game/resources/home_base_resource.tres", "res://game/resources/campaign_resource.tres"]:
		var _resource:SaveableResource = load(_path)
		_saved_names[_resource] = _resource.resource_name
		_resource.resource_name += "_netclient"
		_resource.delete_resource()
		_resource.reset_resource()
	Net.connection_failed.connect(func (reason:String)->void: _report("failed", reason); _finish())
	Net.session_ended.connect(func (reason:String)->void:
		_report("ended", reason)
		get_tree().create_timer(6.0).timeout.connect(_finish))
	Net.state_changed.connect(func ()->void:
		if Net.is_guest():
			_report("joined", str(RunSession.players.local_slot)))
	Transition.instant = true
	var _sound_hook:Callable = SoundResource.played_hook
	SoundResource.played_hook = func (sound:SoundResource)->void:
		if sound.resource_path.ends_with("coin_pickup.tres"):
			_pickup_sounds += 1
		_sound_hook.call(sound)
	var _hook:Callable = InstanceResource.instanced_hook
	InstanceResource.instanced_hook = func (resource:InstanceResource, node:Node)->void:
		if Net.entities._replaying && Net.entities.catalogue.get(resource.resource_path) == NetEntities.Kind.SHOT:
			_cosmetic_shots += 1
		_hook.call(resource, node)
	# stay alive across scene changes: the rooms replace no one
	get_tree().current_scene = null
	Transition.change_scene("res://game/scenes/room_H00.tscn")
	var _reference:ReferenceNodeResource = load("res://addons/top_down/resources/ReferenceNodeResources/player_reference.tres")
	while _reference.node == null || !_reference.node.is_inside_tree():
		await get_tree().process_frame
	_report("join", str(Net.join(address)))
	get_tree().create_timer(60.0).timeout.connect(func ()->void: _report("timeout", ""); _finish())

func _process(delta:float)->void:
	if _mode == "home" || _mode == "ghost":
		_report_left -= delta
		if _report_left <= 0.0:
			_report_left = 0.2
			var _scene:Node = get_tree().current_scene
			var _body:Node2D = Net.players.local_body()
			_report("room", "%s %s" % [_scene.scene_file_path if _scene != null else "-", _body.global_position if _body != null else Vector2.INF])
		return
	if _mode != "world":
		return
	if Net.is_guest() && !_armed:
		_armed = true
		get_tree().create_timer(0.5).timeout.connect(func ()->void:
			var _inventory:ItemCollectionResource = RunSession.local_player().inventory
			_inventory.append(HomeBaseResource.find_item(load("res://addons/top_down/resources/ItemCollectionResource/weapon_database.tres"), "Shotgun"))
			_inventory.set_selected(_inventory.list.size() - 1)
			_report("armed", RunSession.local_player().active_weapon_name()))
	_report_left -= delta
	if _report_left > 0.0:
		return
	_report_left = 0.2
	var _scene:Node = get_tree().current_scene
	var _body:Node2D = Net.players.local_body()
	_report("room", "%s %s" % [_scene.scene_file_path if _scene != null else "-", _body.global_position if _body != null else Vector2.INF])
	for _state:PlayerState in RunSession.players.all():
		if !_state.is_local:
			_report("seen", "%d|%s|%d|%d|%s" % [_state.slot, _state.weapon_name, int(_state.health.hp), int(_state.health.max_hp), _state.room_scene])
	var _ids:Array = Net.entities.entities.keys()
	_ids.sort()
	var _enemies:PackedStringArray = []
	for _id:int in _ids:
		var _copy:Node2D = Net.entities.entities[_id]
		if !is_instance_valid(_copy) || Net.entities.kinds.get(_id) != NetEntities.Kind.ENEMY:
			continue
		_enemies.append("%d@%d,%d" % [_id, roundi(_copy.global_position.x), roundi(_copy.global_position.y)])
		if !_hit_scheduled.has(_id):
			_hit_scheduled[_id] = true
			get_tree().create_timer(0.5).timeout.connect(_hit_copy.bind(_id, 3.0))
			get_tree().create_timer(3.0).timeout.connect(_hit_copy.bind(_id, 9999.0))
	_report("enemies", ";".join(_enemies))
	_report("hp", str(int(RunSession.local_player().health.hp)))
	_report("downed", str(RunSession.local_player().downed))
	if _body != null:
		_report("body_layer", str((_body as CollisionObject2D).collision_layer))
	if _scene != null:
		var _floor:Array = _scene.find_children("*", "ItemPickup", true, false).filter(func (n:Node)->bool: return !n.is_queued_for_deletion())
		_report("floor_weapons", "%d %d" % [_floor.size(), _floor.filter(func (n:Node)->bool: return n.has_meta(&"private_loot")).size()])
	if _body != null && !_body.has_meta(&"net_client_watched"):
		_body.set_meta(&"net_client_watched", true)
		_body.tree_exiting.connect(_on_body_exiting.bind(_body))
	_report("coins", str(LootItems.counter("coin").value))
	_report("cosmetic", str(_cosmetic_shots))
	_report("hit_fx", str(Net.entities.hit_fx_played))
	_report("pickup_sounds", str(_pickup_sounds))
	# enemies here that aren't copies of the host's (should never exist)
	var _own_enemies:int = 0
	for _enemy:Node2D in ActiveEnemy.active_instances:
		if is_instance_valid(_enemy) && _enemy.has_node("ResourceNode") && !_enemy.has_node("NetPuppet"):
			_own_enemies += 1
	_report("own_enemies", str(_own_enemies))
	var _spiders:int = 0
	for _id:int in _ids:
		if Net.entities.kinds.get(_id) == NetEntities.Kind.ENEMY && str(Net.entities._paths.get(_id, "")).contains("skitter_spider"):
			_spiders += 1
	_report("spider_copies", str(_spiders))
	# grind once a little after arriving in the mission (the host put a grinder where we stand)
	if !_ground && _scene != null && _scene.scene_file_path.ends_with("room_N00.tscn") && _body != null && Net.is_guest():
		_grind_wait += 0.2
		if _grind_wait >= 2.0:
			_ground = true
			MeatGrinder.reward_hook.call("health", 1, _body.global_position)
			_report("ground", str(_body.global_position))
	for _section:ArenaSection in NetEntities._sections(_scene):
		_report("section", "%s %s %s" % [_scene.get_path_to(_section), _section.fight_active, _section.is_cleared])
	var _pickups:PackedStringArray = []
	for _id:int in _ids:
		if Net.entities.kinds.get(_id) == NetEntities.Kind.PICKUP && is_instance_valid(Net.entities.entities[_id]):
			_pickups.append("%d@%s" % [_id, Net.entities.entities[_id].global_position])
	_report("pickups", ";".join(_pickups))
	# a real shot every second in the mission, for the host to see copies
	_fire_left -= 0.2
	if _fire_left <= 0.0 && _scene != null && _scene.scene_file_path.ends_with("room_N00.tscn") && _body != null:
		_fire_left = 1.0
		var _bullet:InstanceResource = load("res://addons/top_down/resources/InstanceResources/projectiles/gun_bullet_instance_resource.tres")
		var _from:Vector2 = _body.global_position
		_bullet.instance(func (inst:Projectile2D)->void:
			inst.global_position = _from
			inst.direction = Vector2.LEFT
			inst.damage_data_resource = DamageDataResource.new("damage"))
	for _slot:int in Net.players.puppets:
		var _puppet:Node2D = Net.players.puppets[_slot]
		if is_instance_valid(_puppet):
			_report("puppet", "%d %s" % [_slot, _puppet.global_position])

## Our shot landing on the host's enemy, as DamageDataResource.process does it.
func _hit_copy(id:int, amount:float)->void:
	var _copy:Node = Net.entities.entities.get(id)
	if _copy == null || !is_instance_valid(_copy) || !_copy.is_inside_tree():
		return
	var _data:DamageDataResource = DamageDataResource.new("damage")
	var _type:DamageTypeResource = DamageTypeResource.new()
	_type.value = amount
	_data.base_damage = [_type]
	_data.critical_chance = 0.0
	_data.process(_copy.get_node("ResourceNode"))
	_report("hit", "%d %d" % [id, int(amount)])

func _on_body_exiting(body:Node2D)->void:
	var _health:HealthResource = RunSession.local_player().health
	_report("body_exit", "hp=%s dead=%s transition=%s next=%s" % [_health.hp, _health.is_dead, Transition.bool_resource.value, (load("res://addons/top_down/resources/global_resources/scene_transition_resource.tres") as SceneTransitionResource).next_scene_path])

func _finish()->void:
	if _finishing:
		return
	_finishing = true
	# the home base saves when it leaves the tree: free it while the names are temp
	var _scene:Node = get_tree().current_scene
	if _scene != null:
		_scene.queue_free()
	for _i:int in 4:
		await get_tree().process_frame
	for _resource:SaveableResource in _saved_names:
		_resource.delete_resource()
		_resource.resource_name = _saved_names[_resource]
	_saved_names.clear()
	_quit()

func _report(event:String, detail:String)->void:
	print("NETCLIENT %s %s" % [event, detail])

func _quit()->void:
	get_tree().quit.call_deferred()
