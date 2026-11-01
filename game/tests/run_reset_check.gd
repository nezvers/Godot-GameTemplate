## A new run (Try Again / title / victory) clears weapons and loot, walking back
## into room_start through its stairs keeps them, and an empty inventory falls
## back to the fists weapon. Scene changes are done by hand (Transition needs a
## real screen): free the room, then instance the next one.
##   Godot --headless --path . res://game/tests/run_reset_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const ROOM_START:String = "res://game/scenes/room_start.tscn"
const FISTS:String = TD + "scenes/weapons/fists.tscn"

var failures:int = 0
var checks:int = 0

var _inventory:ItemCollectionResource
var _database:ItemCollectionResource
var _score:ScoreResource
var _transition:SceneTransitionResource
var _player_reference:ReferenceNodeResource
var _room:Node

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	(load(TD + "resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	_inventory = load(TD + "resources/ItemCollectionResource/weapon_inventory.tres")
	_database = load(TD + "resources/ItemCollectionResource/weapon_database.tres")
	_score = load(TD + "resources/global_resources/score_resource.tres")
	_transition = load(TD + "resources/global_resources/scene_transition_resource.tres")
	_player_reference = load(TD + "resources/ReferenceNodeResources/player_reference.tres")

	var _game_over:String = FileAccess.get_file_as_string(TD + "scenes/ui/screens/game_over.tscn")
	check(_game_over.contains('scene_path = "%s"' % ROOM_START), "game over Try Again loads the game room_start")
	check(_game_over.contains('scene_path = "res://game/scenes/title.tscn"'), "game over Main Menu loads the game title")

	# Weapons and coins left over from a previous run
	_inventory.list.clear()
	_inventory.append(_database.list[0])
	_inventory.append(_database.list[1])
	_score.add(7)

	# New run
	await _load_room()
	var _player:Node2D = _player_reference.node
	check(_player != null, "player spawned")
	if _player == null:
		_finish()
		return
	check(_inventory.list.is_empty(), "new run: inventory emptied")
	check(_score.value == 0, "new run: score reset")
	check(_count_pickups() == 3, "new run: starting weapon pickups placed")
	check(!_stairs().visible, "new run: exits locked until pickups are taken")
	var _manager:WeaponManager = _player.get_node("WeaponManager")
	var _fists:Weapon = _manager.current_weapon
	check(_fists != null && _fists.scene_file_path == FISTS, "new run: fists in hand")
	check(_fists != null && _fists.enabled, "fists enabled")
	check(_manager.get_current_weapon_path() == "", "fists are not an inventory weapon")
	if _fists != null:
		var _spawner:ProjectileSpawner = _fists.get_node("ProjectileSpawner")
		check(_spawner.projectile_instance_resource.resource_path.get_file() == "fist_slash_instance_resource.tres", "fists swing the fist slash")
		await _check_fists_damage(_player)

	# Pick up a weapon, then drop it and drop again on the empty inventory
	_inventory.append(_database.list[0])
	await _frames(2)
	check(_manager.current_weapon != _fists && _manager.current_weapon.enabled, "picked weapon replaces fists")
	check(!_fists.enabled, "fists disabled while holding a weapon")
	_inventory.drop()
	await _frames(2)
	check(_manager.current_weapon == _fists && _fists.enabled, "dropping the last weapon goes back to fists")
	check(_inventory.drop() == null, "drop on an empty inventory does nothing")
	check(_manager.current_weapon == _fists, "still fists after an empty drop")

	# Walk out to room_1 and back in through its stairs
	_inventory.append(_database.list[2])
	_score.add(5)
	_transition.next_scene_path = ROOM_START
	_transition.entry_tag = "from_next"
	_player.get_parent().remove_child(_player)
	await _load_room()
	check(_player_reference.node == _player, "door-back: same player carried in")
	check(_player.is_inside_tree(), "door-back: player placed in the room")
	check(_inventory.list.size() == 1 && _inventory.list[0] == _database.list[2], "door-back: weapon kept")
	check(_score.value == 5, "door-back: score kept")
	check(_transition.next_scene_path.is_empty(), "door-back: arrival consumed")
	check(_count_pickups() == 0, "door-back: no new starting pickups")
	check(_stairs().visible && _stairs().collision_mask != 0, "door-back: exits open")
	check(_manager.current_weapon.scene_file_path == _database.list[2].scene_path, "door-back: carried weapon in hand")

	# Die there, Try Again: same room, new run
	await _load_room()
	check(_player_reference.node != null && _player_reference.node != _player, "try again: fresh player")
	check(_inventory.list.is_empty(), "try again: inventory emptied")
	check(_score.value == 0, "try again: score reset")
	check(_count_pickups() == 3, "try again: starting pickups placed")
	_finish()

## Punching the air never hurts the player; a zombie in front takes a small hit.
func _check_fists_damage(player:Node2D)->void:
	var _actions:ActionResource = load(TD + "resources/global_resources/action_resource.tres")
	var _input:InputResource = player.get_node("ResourceNode").get_resource("input")
	var _player_health:HealthResource = player.get_node("ResourceNode").get_resource("health")
	var _player_hp:float = _player_health.hp
	var _shots:Array[int] = [0]
	player.get_node("WeaponManager").current_weapon.get_node("WeaponTrigger").shoot_event.connect(func ()->void: _shots[0] += 1)
	_input.set_aim_direction(Vector2.RIGHT)
	Input.action_press(_actions.action_1_action)
	await _frames(40)
	Input.action_release(_actions.action_1_action)
	await _frames(5)
	check(_shots[0] > 0, "fists swing while attack is held")
	check(_player_health.hp == _player_hp, "fists don't hurt the player (%s -> %s)" % [_player_hp, _player_health.hp])

	var _zombie_resource:InstanceResource = load(TD + "resources/InstanceResources/actors/zomby_instance_resource.tres")
	var _zombie:Node2D = _zombie_resource.instance(func (inst:Node2D)->void: inst.global_position = player.global_position + Vector2(24, 0))
	await _frames(3)
	var _zombie_health:HealthResource = _zombie.get_node("ResourceNode").get_resource("health")
	var _zombie_hp:float = _zombie_health.hp
	_player_hp = _player_health.hp
	_input.set_aim_direction(Vector2.RIGHT)
	Input.action_press(_actions.action_1_action)
	await _frames(20)
	Input.action_release(_actions.action_1_action)
	var _dealt:float = _zombie_hp - _zombie_health.hp
	var _damage:float = float(Balance.value("projectiles.fist_slash.damage"))
	check(_dealt > 0.0 && _dealt <= _damage * 1.5 + 0.01, "fist hit deals the fist_slash damage (%s)" % _dealt)
	check(_player_health.hp == _player_hp, "player unhurt while punching")
	_zombie.queue_free()
	await _frames(2)

## Frees the current room (with whatever player is still in it) and loads room_start.
func _load_room()->void:
	if _room != null:
		_room.queue_free()
		await _frames(2)
	_room = (load(ROOM_START) as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)

func _stairs()->SceneEntry:
	return _room.get_node("Behind/Stairs")

func _count_pickups()->int:
	return _count_script(_room, "ItemPickup")

func _count_script(node:Node, script_name:String)->int:
	var _count:int = 0
	var _script:Script = node.get_script()
	if _script != null && _script.get_global_name() == script_name && node.is_inside_tree():
		_count += 1
	for _child:Node in node.get_children():
		_count += _count_script(_child, script_name)
	return _count

func _finish()->void:
	print("run_reset_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
