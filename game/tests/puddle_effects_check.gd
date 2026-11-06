## Puddles shot by puddle guns: water makes the floor slippery (low acceleration),
## the player's acid puddle hurts enemies but not the player, blood raises the
## damage its stander deals. Also the water gun lobs to the aimed point.
## Runs in the home base control room (no fights), saves go to a temp name.
##   Godot --headless --path . res://game/tests/puddle_effects_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const HOME:String = "res://game/scenes/room_H00.tscn"

var failures:int = 0
var checks:int = 0
var _room:Node
var _home:HomeBaseResource
var _home_name:String

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	var _actions:ActionResource = load(TD + "resources/global_resources/action_resource.tres")
	_actions.reset_resource()
	_home = load("res://game/resources/home_base_resource.tres")
	_home_name = _home.resource_name
	_home.resource_name = _home_name + "_test"
	_home.reset_resource()
	var _inventory:ItemCollectionResource = load(TD + "resources/ItemCollectionResource/weapon_inventory.tres")
	var _database:ItemCollectionResource = load(TD + "resources/ItemCollectionResource/weapon_database.tres")

	_room = (load(HOME) as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)
	var _player:Node2D = (load(TD + "resources/ReferenceNodeResources/player_reference.tres") as ReferenceNodeResource).node
	check(_player != null, "player spawned")
	if _player == null:
		_finish()
		return
	var _stats:ActorStatsResource = _player.get_node("ResourceNode").get_resource("movement")
	var _base_acceleration:float = _stats.acceleration
	var _start:Vector2 = _player.global_position

	# Water
	var _water:Node2D = _puddle("water_puddle", _start)
	await _frames(4)
	check(_stats.get_acceleration() < _base_acceleration * 0.5, "water: player slides (%s of %s)" % [_stats.get_acceleration(), _base_acceleration])
	check(_stats.get_max_speed() == _stats.max_speed, "water: top speed unchanged")
	_water.queue_free()
	await get_tree().create_timer(0.5).timeout
	check(is_equal_approx(_stats.get_acceleration(), _base_acceleration), "water: grip back after leaving")

	# Player acid: enemies only
	var _health:HealthResource = _player.get_node("ResourceNode").get_resource("health")
	var _hp:float = _health.hp
	var _acid:Node2D = _puddle("player_acid_puddle", _start)
	await get_tree().create_timer(0.6).timeout
	check(_health.hp == _hp, "acid: the player is not hurt by their own acid")
	_acid.queue_free()
	var _zombie_resource:InstanceResource = load(TD + "resources/InstanceResources/actors/zomby_instance_resource.tres")
	var _zombie:Node2D = _zombie_resource.instance(func (inst:Node2D)->void: inst.global_position = _start + Vector2(64, 0))
	await _frames(3)
	var _zombie_health:HealthResource = _zombie.get_node("ResourceNode").get_resource("health")
	var _zombie_hp:float = _zombie_health.hp
	var _zombie_acid:Node2D = _puddle("player_acid_puddle", _zombie.global_position)
	await get_tree().create_timer(0.3).timeout
	check(_zombie_health.hp < _zombie_hp, "acid: enemy in the puddle takes damage (%s -> %s)" % [_zombie_hp, _zombie_health.hp])
	_zombie_acid.queue_free()
	var _zombie_water:Node2D = _puddle("water_puddle", _zombie.global_position)
	var _zombie_stats:ActorStatsResource = _zombie.get_node("ResourceNode").get_resource("movement")
	await _frames(4)
	check(_zombie_stats.get_acceleration() < _zombie_stats.acceleration, "water: enemies slide too")
	_zombie_water.queue_free()
	_zombie.queue_free()
	await _frames(2)

	# Blood: more outgoing damage while standing in it
	_inventory.append(_database.list[0])
	await _frames(2)
	var _spawner:ProjectileSpawner = _player.get_node("WeaponManager").current_weapon.get_node("ProjectileSpawner")
	check(is_equal_approx(_spawner._source_damage_multiply(), 1.0), "blood: no bonus outside")
	var _blood:Node2D = _puddle("blood_puddle", _player.global_position)
	await _frames(4)
	check(is_equal_approx(_spawner._source_damage_multiply(), float(Balance.value("player.empowered.damage_multiplier"))), "blood: bonus while standing in it (%s)" % _spawner._source_damage_multiply())
	_blood.queue_free()
	await get_tree().create_timer(0.3).timeout
	check(is_equal_approx(_spawner._source_damage_multiply(), 1.0), "blood: bonus gone after leaving")

	# Water gun lobs to the stick's full range (mouse aim lands on the cursor)
	_inventory.list.clear()
	_inventory.append(HomeBaseResource.find_item(_database, "Water Gun"))
	await _frames(2)
	var _water_gun:Weapon = _player.get_node("WeaponManager").current_weapon
	check(_water_gun.scene_file_path.ends_with("water_gun.tscn"), "water gun in hand")
	var _lob:ProjectileSpawner = _water_gun.get_node("ProjectileSpawner")
	_actions.mouse_aim = false
	_lob.projectile_position = _player.global_position
	_lob.direction = Vector2.RIGHT
	var _expected:Vector2 = _player.global_position + Vector2.RIGHT * _lob.lob_range * _lob.axis_multiplication_resource.value
	check(_lob._lob_destination().distance_to(_expected) < 0.1, "water gun: lands at full range")
	_finish()

func _puddle(id:String, pos:Vector2)->Node2D:
	var _resource:InstanceResource = Balance.instance_resource(id)
	return _resource.instance(func (inst:Node2D)->void: inst.global_position = pos)

func _finish()->void:
	if _room != null:
		_room.queue_free()
		await _frames(3)
	_home.delete_resource()
	_home.resource_name = _home_name
	print("puddle_effects_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
