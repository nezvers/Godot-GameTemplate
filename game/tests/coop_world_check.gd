## Two real games playing together over ENet on 127.0.0.1: this process hosts
## from its home base, a second headless game (net_client.tscn, mode "world")
## joins from its own. Checks that each sees the other's character in the room,
## with the right weapon and HP (in the world and in the party panel on the
## right of the HUD), that the guest follows the host to the mission and through
## a door to the same entrance, that pausing online doesn't freeze the room and
## that a guest whose host leaves goes back to its own home base.
## Save files get temp names (both games), the user's saves stay untouched.
##   Godot --headless --path . res://game/tests/coop_world_check.tscn
extends Node

const PORT:int = 24598
const TD:String = "res://addons/top_down/"
const HOME:String = "res://game/scenes/room_H00.tscn"
const N00:String = "res://game/scenes/room_N00.tscn"

var failures:int = 0
var checks:int = 0
var _client:Dictionary
var _saved_names:Dictionary = {}
var _reference:ReferenceNodeResource

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	for _path:String in ["res://game/resources/home_base_resource.tres", "res://game/resources/campaign_resource.tres"]:
		var _resource:SaveableResource = load(_path)
		_saved_names[_resource] = _resource.resource_name
		_resource.resource_name += "_test"
		_resource.delete_resource()
		_resource.reset_resource()
	(load(TD + "resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	_reference = load(TD + "resources/ReferenceNodeResources/player_reference.tres")
	Transition.instant = true
	# this node outlives the rooms it loads
	get_tree().current_scene = null
	_run.call_deferred()

func _run()->void:
	Transition.change_scene(HOME)
	check(await _wait(func ()->bool: return _body() != null, 10.0), "host: in the home base")
	check(Net.host(PORT) == OK, "host: open to friends")
	_client = _spawn_client()

	# --- the guest walks around in our home base
	check(await _wait(func ()->bool: return RunSession.players.count() == 2, 15.0), "guest joined")
	var _guest:PlayerState = RunSession.players.get_state(1)
	check(await _wait(func ()->bool: return Net.players.puppets.has(1) && is_instance_valid(Net.players.puppets[1]), 10.0), "host: guest's character appears in the room")
	check(_guest != null && _guest.room_scene == HOME, "host: guest reported in the home base")
	var _puppet:Node2D = Net.players.puppets.get(1)
	if _puppet != null:
		check(_puppet.get_node_or_null("PlayerInput") == null && _puppet.get_node_or_null("CameraPositionSetter") == null, "puppet: no local input or camera")
		check(_reference.node == _body() && _reference.node != _puppet, "puppet: player_reference stays ours")
		var _receivers:Array[Node] = _puppet.get_node("AreaReceiver2D").get_children().filter(func (n:Node)->bool: return n is DataChannelReceiver)
		check(_receivers.size() == 1 && _receivers[0].name == "DamageDataReceiver", "puppet: only takes hits, picks nothing up, ignores traps")
		check(_puppet.get_parent() == _body().get_parent(), "puppet: y-sorted with the players")
	check(await _wait(func ()->bool: return _last("puppet").begins_with("0 "), 10.0), "guest: host's character appears in its room")

	# --- weapon in hand and HP reach the other side
	check(await _wait(func ()->bool: return _guest.weapon_name == "Shotgun", 10.0), "host: sees the guest's shotgun")
	_puppet = Net.players.puppets.get(1)
	if _puppet != null:
		var _manager:WeaponManager = _puppet.get_node("WeaponManager")
		var _shotgun:ItemResource = _guest.active_weapon()
		check(_shotgun != null && _manager.get_current_weapon_path() == _shotgun.scene_path, "puppet: holds the shotgun")
	var _panel:PartyPanel = get_tree().current_scene.get_node_or_null("UI/PartyPanel")
	check(_panel != null, "HUD: party panel present")
	if _panel != null:
		await _frames(3)
		check(_panel.visible && _panel.rows.size() == 1 && _panel.rows.has(1), "HUD: one card, for the guest only")
		if _panel.rows.has(1):
			var _row:Dictionary = _panel.rows[1]
			check((_row.weapon as Label).text == "Shotgun" && (_row.icon as TextureRect).texture != null, "HUD: guest's weapon name and icon")
			check((_row.name as Label).text.begins_with(_guest.display_name), "HUD: guest's name")
			check((_row.hp as Label).text == "%d/%d" % [ceili(_guest.health.hp), ceili(_guest.health.max_hp)], "HUD: guest's hp")
		var _rect:Rect2 = _panel.get_global_rect()
		var _width:float = get_viewport().get_visible_rect().size.x
		check(_rect.end.x <= _width && _rect.end.x > _width - 8.0, "HUD: docked to the right edge")
		# run with a window to look at it: the screenshot lands in user://
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://coop_world_hud.png")

	var _local:PlayerState = RunSession.local_player()
	_local.inventory.append(HomeBaseResource.find_item(load(TD + "resources/ItemCollectionResource/weapon_database.tres"), "Gun"))
	_local.health.hp = 37.0
	_local.health.hp_changed.emit()
	check(await _wait(func ()->bool: return _last("seen").begins_with("0|Gun|37|"), 10.0), "guest: sees the host's gun and 37 hp (%s)" % _last("seen"))

	# --- pausing online leaves the room running
	var _pause:BoolResource = load(TD + "resources/global_resources/pause_resource.tres")
	_pause.set_value(true)
	await _frames(2)
	check(get_tree().current_scene.process_mode != Node.PROCESS_MODE_DISABLED, "pause online: room keeps running")
	check(!(_body().get_node("PlayerInput") as PlayerInput).enabled, "pause online: our player stops")
	_pause.set_value(false)
	await _frames(2)
	check((_body().get_node("PlayerInput") as PlayerInput).enabled, "unpause: our player moves again")

	# --- the party leaves for a mission; the guest follows
	Transition.change_scene(N00)
	check(await _wait(func ()->bool: return _current() == N00 && _body() != null, 10.0), "host: in the mission start")
	# a grinder where both players arrive: the guest grinds there (net_client)
	var _grinder:MeatGrinder = (load(TD + "scenes/interactables/meat_grinder.tscn") as PackedScene).instantiate()
	_grinder.name = "TestGrinder"
	get_tree().current_scene.add_child(_grinder)
	_grinder.global_position = _body().global_position
	var _health_path:String = LootItems.PICKUPS.health
	var _tracked_health:Array[int] = [0]
	var _private_spawns:Array[int] = [0]
	var _grind_hook:Callable = InstanceResource.instanced_hook
	InstanceResource.instanced_hook = func (resource:InstanceResource, node:Node)->void:
		_grind_hook.call(resource, node)
		if resource.resource_path == _health_path:
			if Net.entities._ids.has(node.get_instance_id()):
				_tracked_health[0] += 1
			else:
				_private_spawns[0] += 1
	check(await _wait(func ()->bool: return _last("room").begins_with(N00), 15.0), "guest: followed to the mission (%s)" % _last("room"))
	check(await _wait(func ()->bool: return Net.players.puppets.has(1) && is_instance_valid(Net.players.puppets[1]), 10.0), "host: guest's character in the mission room")
	# the start room's weapon: one each, rolled on each machine, never shared
	await _frames(5)
	var _starting:Array = get_tree().current_scene.find_children("*", "ItemPickup", true, false).filter(func (n:Node)->bool: return !n.is_queued_for_deletion())
	check(_starting.size() == 1 && _starting[0].has_meta(&"private_loot"), "host: one starting weapon here, our own (%d)" % _starting.size())
	check(!Net.entities.kinds.values().has(NetEntities.Kind.ITEM), "host: the starting weapon isn't sent to guests")
	check(await _wait(func ()->bool: return _last("floor_weapons") == "1 1", 5.0), "guest: one starting weapon of its own, not ours on top (%s)" % _last("floor_weapons"))

	# per-player loot is on in balance.json: the grind still makes one shared pickup
	check(await _wait(func ()->bool: return _last("ground") != "", 10.0), "guest: ground meat")
	check(await _wait(func ()->bool: return _tracked_health[0] == 1, 5.0), "host: the guest's grinder health shows up here, shared (%d tracked, %d untracked)" % [_tracked_health[0], _private_spawns[0]])
	InstanceResource.instanced_hook = _grind_hook
	var _before_host_grind:int = _tracked_health[0]
	_tracked_health[0] = 0
	_private_spawns[0] = 0
	InstanceResource.instanced_hook = func (resource:InstanceResource, node:Node)->void:
		_grind_hook.call(resource, node)
		if resource.resource_path == _health_path:
			if Net.entities._ids.has(node.get_instance_id()):
				_tracked_health[0] += 1
			else:
				_private_spawns[0] += 1
	_grinder.rewards = [{"drop": "health", "amount": 1}]
	_grinder._finish()
	await _frames(3)
	check(_tracked_health[0] == 1 && _private_spawns[0] == 0 && _before_host_grind == 1, "host: our own grind is one shared pickup, no free copies for guests (%d/%d)" % [_tracked_health[0], _private_spawns[0]])
	InstanceResource.instanced_hook = _grind_hook
	_grinder.queue_free()

	await _check_world(_guest)

	# --- through a door: the guest comes out of the same one
	var _stairs:SceneEntry = get_tree().current_scene.get_node("Behind/Stairs")
	var _next:String = _stairs.scene_path
	_stairs.scene_transition_resource.set_next_scene(_next, _stairs.connect_tag)
	check(await _wait(func ()->bool: return _current() == _next && _body() != null && !Transition.bool_resource.value, 10.0), "host: through the stairs")
	check(await _wait(func ()->bool: return _last("room").begins_with(_next), 15.0), "guest: followed through the door")
	await _frames(10)
	var _guest_at:Vector2 = _vector(_last("room").get_slice(" ", 1) + " " + _last("room").get_slice(" ", 2))
	check(_guest_at.distance_to(_body().global_position) < 48.0, "guest: arrived at the same door (%s vs %s)" % [_guest_at, _body().global_position])

	# --- a fight starts on the host: the guest's copy of the section follows
	var _sections:Array[ArenaSection] = NetEntities._sections(get_tree().current_scene)
	if !_sections.is_empty():
		var _section:ArenaSection = _sections[0]
		# the host steps in away from the guest: the gates close, the guest is pulled over
		_body().global_position += Vector2(40, 0)
		await _frames(4)
		_section.try_start(_body())
		var _key:String = str(get_tree().current_scene.get_path_to(_section))
		check(await _wait(func ()->bool: return _section_line(_key).contains("true"), 10.0), "guest: fight started with the host's (%s)" % _section_line(_key))
		_section.spawn_holds += 1
		var _pulled:Callable = func ()->Vector2: return _vector(_last("room").get_slice(" ", 1) + " " + _last("room").get_slice(" ", 2))
		check(await _wait(func ()->bool: return _pulled.call().distance_to(_body().global_position) < 12.0, 5.0), "guest: pulled to the host when the gates closed (%s vs %s)" % [_pulled.call(), _body().global_position])

	# --- everyone down: the run ends for both
	var _guest_state:PlayerState = RunSession.players.get_state(1)
	await _wait(func ()->bool: return Net.players.puppets.has(1) && is_instance_valid(Net.players.puppets[1]), 5.0)
	_hurt_guest(9999.0)
	check(await _wait(func ()->bool: return _guest_state != null && _guest_state.downed, 5.0), "wipe: guest down first")
	# more hits while down, past the hit cooldown: nothing lands, nothing breaks
	for _i:int in 4:
		await get_tree().create_timer(0.4).timeout
		_hurt_guest(5.0)
	await _frames(10)
	check(_guest_state.downed && !_read().contains("Assertion failed") && !_read().contains("SCRIPT ERROR"), "downed: later hits are refused on both machines")
	var _health:HealthResource = RunSession.local_player().health
	var _all_down:Array[bool] = [false]
	RunSession.players.all_downed.connect(func ()->void: _all_down[0] = true, CONNECT_ONE_SHOT)
	_health.add_hp(-99999.0)
	check(_all_down[0], "wipe: host down too, nobody left standing")
	check(_health.is_dead, "wipe: then everyone dies for real")
	var _game_over:String = "res://addons/top_down/scenes/ui/screens/game_over.tscn"
	check(await _wait(func ()->bool: return _current() == _game_over, 10.0), "wipe: host at game over (%s)" % _current())
	check(await _wait(func ()->bool: return _last("room").begins_with(_game_over), 10.0), "wipe: guest at game over (%s)" % _last("room"))

	# --- back home together, then the host leaves: the guest stays at its home base
	RunSession.local_player().health.reset_resource()
	Transition.change_scene(HOME)
	check(await _wait(func ()->bool: return _last("room").begins_with(HOME), 15.0), "guest: followed home after the game over")
	Net.leave()
	check(await _wait(func ()->bool: return _read().contains("NETCLIENT ended The host left"), 10.0), "guest: told the host left")
	await _frames(30)
	check(_last("room").begins_with(HOME), "guest: still in its own home base")
	check(Net.players.puppets.is_empty(), "host: puppets gone once offline")
	_finish()

## A slime's charge and a Big Jelly's jump look the same on the guest's copies:
## windup with its telegraph, then the jelly hops (sprite leaves the ground).
func _check_enemy_actions()->void:
	var _tame:Callable = func (path:String, at:Vector2)->Node2D:
		return (load(TD + "resources/InstanceResources/actors/" + path) as InstanceResource).instance(func (inst:Node2D)->void:
			inst.global_position = at
			for _node:Node in inst.get_children():
				if !NetEntities.PUPPET_KEEP.has(_node.name):
					_node.process_mode = Node.PROCESS_MODE_DISABLED)
	var _slime:Node2D = _tame.call("slime_instance_resource.tres", _body().global_position + Vector2(-90, 0))
	var _jelly:Node2D = _tame.call("boss_slime_instance_resource.tres", _body().global_position + Vector2(0, -90))
	var _copies:Callable = func ()->int: return _last("enemies").split(";", false).size()
	check(await _wait(func ()->bool: return _copies.call() >= 2, 10.0), "guest: slime and jelly copies (%s)" % _last("enemies"))
	var _attacks_before:int = int(_last("attacks"))
	var _loop:BossAttackLoop = _slime.get_node("BossAttackLoop")
	_loop_attack(_loop, _loop.attacks[0])
	check(await _wait(func ()->bool: return int(_last("attacks")) >= _attacks_before + 1, 5.0), "guest: slime's windup played on its copy (%s)" % _last("attacks"))
	check(await _wait(func ()->bool: return int(_last("telegraphs")) > 0, 3.0), "guest: charge telegraph shown (%s)" % _last("telegraphs"))
	check(await _wait(func ()->bool: return int(_last("attacks")) >= _attacks_before + 2, 5.0), "guest: charge played on its copy (%s)" % _last("attacks"))
	# its AI may have jumped on spawn, before the guest had a copy: land it first
	var _move:JumpMove = _jelly.find_children("*", "JumpMove", true, false)[0]
	_move.cancel()
	var _jumps_before:int = int(_last("jumps"))
	_move.move_target_position(_jelly.global_position + Vector2(20, 0), 1.0)
	check(await _wait(func ()->bool: return int(_last("jumps")) == _jumps_before + 1, 5.0), "guest: jelly's jump played on its copy (%s)" % _last("jumps"))
	check(await _wait(func ()->bool: return absi(int(_last("hop"))) > 4, 3.0), "guest: jelly copy hops (%s)" % _last("hop"))
	check(await _wait(func ()->bool: return int(_last("landings")) >= 1, 3.0), "guest: jelly copy's landing splash (%s)" % _last("landings"))

	# the bloater's jump attack: windup with the landing circle, hop, dust ring on landing
	# next to us, so it lands on our floor (not in a hole); its landing mustn't hurt us
	var _our_damage:DamageResource = (_body().get_node("ResourceNode") as ResourceNode).get_resource("damage")
	_our_damage.immune = true
	var _bloater:Node2D = _tame.call("bloater_instance_resource.tres", _body().global_position + Vector2(30, 0))
	await _frames(2)
	# the guest's scripted hits on copies must not kill it or bring on a burst
	(_bloater.get_node("ResourceNode") as ResourceNode).get_resource("damage").immune = true
	var _bloater_id:int = _net_id(_bloater)
	check(await _wait(func ()->bool: return _enemy_at(_bloater_id).is_finite(), 10.0), "guest: bloater copy (%s)" % _last("enemies"))
	var _bloater_loop:BossAttackLoop = _bloater.get_node("BossAttackLoop")
	var _bloater_jump:BossJump = _bloater_loop.attacks[0]
	# moved by JumpMove here: switched on like in a real fight
	_bloater.get_node("JumpMove").process_mode = Node.PROCESS_MODE_INHERIT
	_bloater_jump.burst_chance = 0.0
	_attacks_before = int(_last("attacks"))
	_jumps_before = int(_last("jumps"))
	var _landings_before:int = int(_last("landings"))
	_loop_attack(_bloater_loop, _bloater_jump)
	check(await _wait(func ()->bool: return int(_last("attacks")) >= _attacks_before + 1, 5.0), "guest: bloater's windup played on its copy (%s)" % _last("attacks"))
	check(await _wait(func ()->bool: return _vector(_last("circle_at")).distance_to(_bloater_jump.landing_position) < 1.0, 3.0), "guest: bloater's landing circle at the host's spot (%s vs %s)" % [_last("circle_at"), _bloater_jump.landing_position])
	check(await _wait(func ()->bool: return int(_last("jumps")) == _jumps_before + 1, 5.0), "guest: bloater's jump played on its copy (%s)" % _last("jumps"))
	check(await _wait(func ()->bool: return int(_last("landings")) == _landings_before + 1, 5.0), "guest: bloater copy's dust ring on landing (%s)" % _last("landings"))
	check(await _wait(func ()->bool: return int(_last("attacks")) >= _attacks_before + 3, 5.0), "guest: bloater's attack ended on its copy (%s)" % _last("attacks"))
	await _frames(10)
	check(int(_last("landings")) == _landings_before + 1, "guest: one dust ring per landing (%s)" % _last("landings"))

	# a burst pops it right on landing: the copy still lands and rings before it goes
	_bloater_jump.burst_health = 1.0
	_bloater_jump.burst_chance = 1.0
	_landings_before = int(_last("landings"))
	_loop_attack(_bloater_loop, _bloater_jump)
	check(await _wait(func ()->bool: return !_enemy_at(_bloater_id).is_finite(), 6.0), "guest: burst bloater copy gone (%s)" % _last("enemies"))
	check(await _wait(func ()->bool: return int(_last("landings")) == _landings_before + 1, 2.0), "guest: burst bloater's dust ring still shows (%s)" % _last("landings"))

	_our_damage.immune = false
	var _left_ids:Array = [_net_id(_slime), _net_id(_jelly)].filter(func (k:int)->bool: return k != 0)
	for _enemy:Node2D in [_slime, _jelly, _bloater]:
		if is_instance_valid(_enemy) && _enemy.is_inside_tree():
			(_enemy.get_node("ResourceNode") as ResourceNode).get_resource("health").insta_kill()
	check(await _wait(func ()->bool: return _left_ids.all(func (k:int)->bool: return !_enemy_at(k).is_finite()), 6.0), "guest: copies gone (%s)" % _last("enemies"))

## Host's net id of `node` (0 if it has none).
func _net_id(node:Variant)->int:
	if !is_instance_valid(node):
		return 0
	for _key:int in Net.entities.entities:
		if Net.entities.entities[_key] == node:
			return _key
	return 0

## Starts `attack` on a tame enemy's loop at once, aimed at our body.
func _loop_attack(loop:BossAttackLoop, attack:BossAttack)->void:
	loop._run_attack(attack, _body())

## Enemies, hits both ways, shots and loot, with one tame zombie the host owns.
func _check_world(guest:PlayerState)->void:
	var _zombie_resource:InstanceResource = load(TD + "resources/InstanceResources/actors/zomby_instance_resource.tres")
	var _at:Vector2 = _body().global_position + Vector2(120, 0)
	# kept still and harmless: only the network part is under test
	var _zombie:Node2D = _zombie_resource.instance(func (inst:Node2D)->void:
		inst.global_position = _at
		for _node:Node in inst.get_children():
			if !NetEntities.PUPPET_KEEP.has(_node.name):
				_node.process_mode = Node.PROCESS_MODE_DISABLED)
	await _frames(2)
	var _id:int = -1
	for _key:int in Net.entities.entities:
		if Net.entities.entities[_key] == _zombie:
			_id = _key
	check(_id > 0 && Net.entities.kinds[_id] == NetEntities.Kind.ENEMY, "host: zombie got a net id")
	check(await _wait(func ()->bool: return _enemy_at(_id).is_finite(), 10.0), "guest: zombie copy appears (%s)" % _last("enemies"))
	check(_enemy_at(_id).distance_to(_at) < 8.0, "guest: copy where the zombie is (%s vs %s)" % [_enemy_at(_id), _at])
	# our hit flashes and sounds on the guest's copy too
	var _health:HealthResource = (_zombie.get_node("ResourceNode") as ResourceNode).get_resource("health")
	var _fx_before:int = int(_last("hit_fx"))
	NetEntities.apply_hit(_zombie, 1.0, Vector2.ZERO, false)
	var _max:float = _health.hp
	check(await _wait(func ()->bool: return int(_last("hit_fx")) == _fx_before + 1, 5.0), "guest: our hit flashes its copy (%s)" % _last("hit_fx"))
	_zombie.global_position += Vector2(0, 30)
	check(await _wait(func ()->bool: return _enemy_at(_id).distance_to(_zombie.global_position) < 4.0, 5.0), "guest: copy follows the zombie")

	check(await _wait(func ()->bool: return _health.hp < _max, 5.0), "host: guest's hit lands on the zombie (%d/%d)" % [_health.hp, _max])
	check(is_equal_approx(_max - _health.hp, 3.0), "host: hit for the 3 the guest measured (%s)" % (_max - _health.hp))
	check(await _wait(func ()->bool: return !Net.entities.entities.has(_id), 6.0), "host: guest killed the zombie")
	check(await _wait(func ()->bool: return !_enemy_at(_id).is_finite(), 5.0), "guest: copy gone with it")
	check(int(_last("hit_fx")) == _fx_before + 1, "guest: its own hits aren't echoed back (%s)" % _last("hit_fx"))

	await _check_enemy_actions()

	# a spiderling lobbed here hatches one spider, ours; the guest gets a copy, not its own
	var _spiderling:InstanceResource = load(TD + "resources/InstanceResources/projectiles/spiderling_projectile_instance_resource.tres")
	var _lob_from:Vector2 = _body().global_position + Vector2(60, 0)
	_spiderling.instance(func (inst:Projectile2D)->void:
		inst.global_position = _lob_from
		inst.destination = _lob_from + Vector2(20, 0)
		inst.direction = Vector2.RIGHT)
	var _spider_ids:Callable = func ()->Array:
		return Net.entities.entities.keys().filter(func (k:int)->bool: return Net.entities.kinds.get(k) == NetEntities.Kind.ENEMY && str(Net.entities._paths.get(k, "")).contains("skitter_spider"))
	check(await _wait(func ()->bool: return _spider_ids.call().size() == 1, 6.0), "host: the spiderling hatched a spider here (%d)" % _spider_ids.call().size())
	check(await _wait(func ()->bool: return _last("spider_copies") == "1", 5.0), "guest: sees our spider (%s)" % _last("spider_copies"))
	await _frames(30)
	check(_last("own_enemies") == "0", "guest: no spider of its own hatched from the shot copy (%s)" % _last("own_enemies"))
	for _spider_id:int in _spider_ids.call():
		var _spider:Node = Net.entities.entities[_spider_id]
		(_spider.get_node("ResourceNode") as ResourceNode).get_resource("health").insta_kill()
	check(await _wait(func ()->bool: return _last("spider_copies") == "0", 5.0), "guest: spider gone with ours (%s)" % _last("spider_copies"))

	# an enemy hit on the guest's copy here lands on the guest there
	var _hp_before:int = int(_last("hp"))
	var _puppet:Node2D = Net.players.puppets.get(1)
	var _blow:DamageDataResource = DamageDataResource.new("damage")
	var _type:DamageTypeResource = DamageTypeResource.new()
	_type.value = 4.0
	_blow.base_damage = [_type]
	_blow.critical_chance = 0.0
	if _puppet != null:
		var _puppet_health:HealthResource = (_puppet.get_node("ResourceNode") as ResourceNode).get_resource("health")
		var _copy_hp:float = _puppet_health.hp
		_blow.process(_puppet.get_node("ResourceNode"))
		check(is_equal_approx(_puppet_health.hp, _copy_hp), "host: the hit isn't applied to the copy")
	check(await _wait(func ()->bool: return int(_last("hp")) < _hp_before, 5.0), "guest: took the host's hit (%d -> %s)" % [_hp_before, _last("hp")])
	check(await _wait(func ()->bool: return guest.health.hp < _hp_before, 5.0), "host: guest's lower hp comes back")

	# shots: ours shows up there, theirs here
	var _copies:Array[int] = [0]
	var _hook:Callable = InstanceResource.instanced_hook
	InstanceResource.instanced_hook = func (resource:InstanceResource, node:Node)->void:
		if Net.entities._replaying && Net.entities.catalogue.get(resource.resource_path) == NetEntities.Kind.SHOT:
			_copies[0] += 1
			check((node as Projectile2D).damage_data_resource.base_damage.is_empty() && ((node as Projectile2D).collision_mask & ~1) == 0, "shot copy: no damage, walls only")
		_hook.call(resource, node)
	var _shots_seen:int = int(_last("cosmetic"))
	var _bullet:InstanceResource = load(TD + "resources/InstanceResources/projectiles/gun_bullet_instance_resource.tres")
	var _from:Vector2 = _body().global_position
	_bullet.instance(func (inst:Projectile2D)->void:
		inst.global_position = _from
		inst.direction = Vector2.UP
		inst.damage_data_resource = DamageDataResource.new("damage"))
	check(await _wait(func ()->bool: return int(_last("cosmetic")) > _shots_seen, 5.0), "guest: sees the host's shot")
	check(await _wait(func ()->bool: return _copies[0] > 0, 5.0), "host: sees the guest's shot")
	InstanceResource.instanced_hook = _hook

	# loot: dropped on the guest, picked up there, gone here, credited there only
	# (shared loot for this part: per-player loot is never sent)
	var _coop_balance:Dictionary = Balance.data.get("coop", {})
	var _per_player:Variant = _coop_balance.get("loot_per_player", false)
	_coop_balance["loot_per_player"] = false
	var _coin_sounds:Array[int] = [0]
	var _sound_hook:Callable = SoundResource.played_hook
	SoundResource.played_hook = func (sound:SoundResource)->void:
		if sound.resource_path.ends_with("coin_pickup.tres"):
			_coin_sounds[0] += 1
		_sound_hook.call(sound)
	var _guest_coin_sounds:int = int(_last("pickup_sounds"))
	var _coins_here:int = LootItems.counter("coin").value
	var _coins_there:int = int(_last("coins"))
	var _drop_at:Vector2 = _puppet.global_position if _puppet != null else _from
	# both players start on the same marker: step aside so only the guest is on it
	_body().global_position = _at
	await _frames(3)
	LootItems.spawn("coin", 1, _drop_at)
	await _frames(2)
	var _coin_id:int = -1
	for _key:int in Net.entities.kinds:
		if Net.entities.kinds[_key] == NetEntities.Kind.PICKUP:
			_coin_id = _key
	check(_coin_id > 0, "host: coin got a net id")
	check(await _wait(func ()->bool: return int(_last("coins")) == _coins_there + 1, 8.0), "guest: picked up the coin (%s)" % _last("coins"))
	check(await _wait(func ()->bool: return !Net.entities.entities.has(_coin_id), 5.0), "host: coin gone once the guest has it")
	check(LootItems.counter("coin").value == _coins_here, "host: the guest's coin isn't ours")
	check(_coin_sounds[0] == 1, "host: hears the guest take the coin (%d)" % _coin_sounds[0])
	await _frames(10)
	check(int(_last("pickup_sounds")) == _guest_coin_sounds + 1, "guest: its pickup sound once, no echo (%s)" % _last("pickup_sounds"))
	SoundResource.played_hook = _sound_hook
	_coop_balance["loot_per_player"] = _per_player

	# down, not dead: a teammate standing close brings them back
	_hurt_guest(9999.0)
	check(await _wait(func ()->bool: return _last("downed") == "true", 5.0), "guest: down instead of dead (%s, hp %s)" % [_last("downed"), _last("hp")])
	check(await _wait(func ()->bool: return guest.downed, 5.0), "host: sees the guest down")
	var _panel:PartyPanel = get_tree().current_scene.get_node_or_null("UI/PartyPanel")
	if _panel != null && _panel.rows.has(1):
		await _frames(2)
		check((_panel.rows[1].name as Label).text.contains("DOWN"), "HUD: guest's card says DOWN")
	_puppet = Net.players.puppets.get(1)
	check(await _wait(func ()->bool: return _last("body_layer") == "0", 5.0), "guest: off the body layer while down, enemies can't shove it (%s)" % _last("body_layer"))
	if _puppet != null:
		check(is_equal_approx((_puppet.get_node("Body") as Node2D).rotation, PI * 0.5), "puppet: lies on the floor")
		await _frames(2)
		check((_puppet as CollisionObject2D).collision_layer == 0, "puppet: enemies here don't chase a downed copy")
		check(_puppet.get_node_or_null(ReviveAssist.LABEL_NAME) == null, "revive: no prompt from across the room")
		_body().global_position = _puppet.global_position + Vector2(6, 0)
		await _frames(3)
		var _prompt:Label = _puppet.get_node_or_null(ReviveAssist.LABEL_NAME) as Label
		check(_prompt != null && _prompt.text.ends_with("to REVIVE"), "revive: prompt over the downed teammate in range (%s)" % (_prompt.text if _prompt != null else "none"))
	var _revive_s:float = CoopScaling.revive_time()
	await _frames(int(_revive_s * 60.0) + 30)
	check(_last("downed") == "true", "revive: standing by without the key does nothing")
	ReviveAssist.force_hold = true
	check(await _wait(func ()->bool: return _last("downed") == "false", _revive_s + 4.0), "guest: revived by the host holding the key")
	ReviveAssist.force_hold = false
	check(_last("body_layer") != "0", "guest: solid again once up")
	var _max_hp:float = guest.health.max_hp
	check(abs(int(_last("hp")) - roundi(_max_hp * CoopScaling.revive_hp_ratio())) <= 1, "guest: back with %d%% hp (%s of %d)" % [roundi(CoopScaling.revive_hp_ratio() * 100), _last("hp"), _max_hp])
	check(await _wait(func ()->bool: return !guest.downed, 5.0), "host: sees the guest up again")

	# a continued co-op run: the guest's saved state goes back to it on return
	check(await _wait(func ()->bool: return guest.guest_run_data != null, 5.0), "host: keeps the guest's own run state for the checkpoint")
	var _saved:PlayerRunData = PlayerRunData.new()
	_saved.max_hp = guest.health.max_hp
	_saved.hp = 33.0
	_saved.weapons = PackedStringArray(["Gun"])
	_saved.wallet = {"coin": {"value": 42, "collected_total": 42}}
	RunSession.waiting_guests[guest.profile_id] = _saved
	Net.players._return_saved_guests()
	check(!RunSession.waiting_guests.has(guest.profile_id), "host: saved guest handed back")
	check(await _wait(func ()->bool: return _last("coins") == "42" && _last("hp") == "33", 5.0), "guest: got its saved coins and hp back (%s, %s)" % [_last("coins"), _last("hp")])
	check(await _wait(func ()->bool: return guest.weapon_name == "Gun", 5.0), "guest: holds its saved gun")

## An enemy hit on the guest's copy, as DamageDataResource.process does it.
func _hurt_guest(amount:float)->void:
	var _puppet:Node2D = Net.players.puppets.get(1)
	if _puppet == null:
		return
	var _blow:DamageDataResource = DamageDataResource.new("damage")
	var _type:DamageTypeResource = DamageTypeResource.new()
	_type.value = amount
	_blow.base_damage = [_type]
	_blow.critical_chance = 0.0
	_blow.process(_puppet.get_node("ResourceNode"))

func _enemy_at(id:int)->Vector2:
	for _entry:String in _last("enemies").split(";", false):
		if _entry.get_slice("@", 0) == str(id):
			var _xy:PackedStringArray = _entry.get_slice("@", 1).split(",")
			return Vector2(float(_xy[0]), float(_xy[1]))
	return Vector2.INF

func _section_line(path:String)->String:
	var _lines:PackedStringArray = _read().split("\n")
	for _i:int in range(_lines.size() - 1, -1, -1):
		if _lines[_i].begins_with("NETCLIENT section %s " % path):
			return _lines[_i]
	return ""

func _finish()->void:
	if OS.is_process_running(_client.get("pid", -1)):
		await _wait(func ()->bool: return !OS.is_process_running(_client.pid), 10.0)
		if OS.is_process_running(_client.pid):
			OS.kill(_client.pid)
	if failures > 0:
		printerr(_read().right(3000))
		# whole guest log kept for a look
		DirAccess.copy_absolute(_client.get("log", ""), ProjectSettings.globalize_path("user://coop_world_guest_last.log"))
	DirAccess.remove_absolute(_client.get("log", ""))
	var _scene:Node = get_tree().current_scene
	if _scene != null:
		_scene.queue_free()
	await _frames(4)
	RunSave.delete_file()
	for _resource:SaveableResource in _saved_names:
		_resource.delete_resource()
		_resource.resource_name = _saved_names[_resource]
	print("coop_world_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _body()->Node2D:
	return Net.players.local_body()

func _current()->String:
	var _scene:Node = get_tree().current_scene
	return _scene.scene_file_path if _scene != null else ""

func _spawn_client()->Dictionary:
	var _log:String = ProjectSettings.globalize_path("user://net_client_world_%d.log" % Time.get_ticks_msec())
	var _cmd:String = "'%s' --headless --path '%s' res://game/tests/net_client.tscn -- 127.0.0.1:%d world --instant-transitions > '%s' 2>&1" % [
		OS.get_executable_path(), ProjectSettings.globalize_path("res://"), PORT, _log]
	return {"pid": OS.create_process("/bin/sh", ["-c", _cmd]), "log": _log}

func _read()->String:
	return FileAccess.get_file_as_string(_client.log) if FileAccess.file_exists(_client.get("log", "")) else ""

## Detail of the client's latest "NETCLIENT <event> ..." line.
func _last(event:String)->String:
	var _lines:PackedStringArray = _read().split("\n")
	var _prefix:String = "NETCLIENT %s " % event
	for _i:int in range(_lines.size() - 1, -1, -1):
		if _lines[_i].begins_with(_prefix):
			return _lines[_i].substr(_prefix.length())
	return ""

static func _vector(text:String)->Vector2:
	var _parts:PackedStringArray = text.strip_edges().trim_prefix("(").trim_suffix(")").split(",")
	if _parts.size() != 2:
		return Vector2.INF
	return Vector2(float(_parts[0]), float(_parts[1]))

func _wait(condition:Callable, seconds:float)->bool:
	var _end:int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < _end:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()

func _frames(count:int)->void:
	for _i:int in count:
		await get_tree().physics_frame
