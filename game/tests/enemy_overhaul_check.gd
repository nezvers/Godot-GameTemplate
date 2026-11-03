## Enemy special attacks and the weapon-wielding enemies: slime dashes, acid slime spits, bloater jumps
## (and bursts into zombies at low health), skeleton and mage weapons hit the player and never enemies.
##   Godot --headless --path . res://game/tests/enemy_overhaul_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const ACTORS:String = TD + "resources/InstanceResources/actors/"
const ROOM:String = "res://game/scenes/room_A02.tscn"

var failures:int = 0
var checks:int = 0
var player:Node2D
var player_health:HealthResource
var player_hits:int
var astar:AStarGrid2D
var tilemap:TileMapLayer

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	var _room:Node = (load(ROOM) as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)
	player = (load(TD + "resources/ReferenceNodeResources/player_reference.tres") as ReferenceNodeResource).node
	var _grid_resource:AstarGridResource = load(TD + "resources/arena_resources/obstacle_astargrid_resource.tres")
	astar = _grid_resource.value
	tilemap = _grid_resource.tilemap_layer
	check(player != null && astar != null, "room has player and grid")
	if player == null || astar == null:
		_finish()
		return
	player_health = player.get_node("ResourceNode").get_resource("health")
	player_health.damaged.connect(func ()->void: player_hits += 1)

	await _check_slime()
	await _check_bloater()
	await _check_bloater_out_of_range()
	await _check_bloater_burst()
	await _check_wielder("skeleton", "skeleton_slash.tscn", 14.0)
	await _check_wielder("mage", "mage_bullet.tscn", 60.0)
	# last: its acid puddle under the player would keep the player in hit cooldown
	await _check_acid_slime()
	_finish()

func _check_slime()->void:
	var _slime:Node2D = await _spawn("slime_instance_resource.tres", 64.0)
	var _loop:BossAttackLoop = _slime.get_node("BossAttackLoop")
	var _charge:BossCharge = _loop.get_node("Charge")
	check(is_equal_approx(_charge.cooldown, 7.0) && is_equal_approx(_charge.speed, 130.0), "slime charge values come from balance")
	var _hits:Array[int] = [0]
	_slime.get_node("ChargeDamage/DamageDataTransmitter").success.connect(func ()->void: _hits[0] += 1)
	_loop.next_attack_time = 0.0
	var _charged:bool = false
	for i:int in 150:
		await get_tree().physics_frame
		_keep_player()
		_charged = _charged || _loop.current == _charge
	check(_charged, "slime dashes at the player")
	check(_hits[0] == 1, "slime dash hits the player once (%d)" % _hits[0])
	_kill(_slime)
	await _frames(3)

func _check_acid_slime()->void:
	var _acid:Node2D = await _spawn("acid_slime_instance_resource.tres", 64.0)
	var _lob:EnemyLob = _acid.get_node("EnemyLob")
	check(is_equal_approx(_lob.cooldown, 6.0), "acid slime lob values come from balance")
	_lob.next_shot_time = 0.0
	var _spits:int = 0
	for i:int in 10:
		await get_tree().physics_frame
		_keep_player()
		_spits = maxi(_spits, _count_scene("acid_spit_projectile.tscn"))
	check(_spits == 1, "acid slime spits an acid ball at the player (%d)" % _spits)
	# no second shot inside the cooldown
	_lob.next_shot_time = Time.get_ticks_msec() * 0.001 + _lob.cooldown
	_kill(_acid)
	await _frames(3)

func _check_bloater()->void:
	var _bloater:Node2D = await _spawn("bloater_instance_resource.tres", 48.0)
	var _loop:BossAttackLoop = _bloater.get_node("BossAttackLoop")
	var _jump:BossJump = _loop.get_node("Jump")
	_jump.burst_chance = 0.0
	check(is_equal_approx(_jump.cooldown, 8.0) && is_equal_approx(_jump.max_distance, 80.0), "bloater jump values come from balance")
	check(_bloater.get_node("SlimeSplit").angles.size() == 3, "bloater releases 3 zombies")
	var _hits:Array[int] = [0]
	_bloater.get_node("JumpDamage/DamageDataTransmitter").success.connect(func ()->void: _hits[0] += 1)
	_loop.next_attack_time = 0.0
	var _jumped:bool = false
	var _landed_at:Array[Vector2] = []
	# sampled before the landing push moves the player
	_jump.jump_move.jump_finished.connect(func ()->void: _landed_at.append(_bloater.global_position - player.global_position), CONNECT_ONE_SHOT)
	var _peak:float = 0.0
	var _sprite:Sprite2D = _bloater.get_node("Body/Stretch/Sprite2D")
	for i:int in 150:
		await get_tree().physics_frame
		_keep_player()
		_jumped = _jumped || _jump.is_jumping
		_peak = minf(_peak, _sprite.offset.y)
	check(_jumped && _peak < -8.0, "bloater jumps into the air (peak %.1f)" % _peak)
	check(_hits[0] == 1, "bloater landing hits the player (%d)" % _hits[0])
	check(_landed_at.size() == 1 && _landed_at[0].length() < 8.0, "bloater lands on the player's spot %s" % [_landed_at])
	check(is_zero_approx(_sprite.offset.y) && _bloater.collision_mask == 5, "bloater body restored after landing")
	check(!_bloater.get_node("ResourceNode").get_resource("health").is_dead, "full health bloater does not burst")
	_kill(_bloater)
	await _frames(3)
	_kill_scene("zombie.tscn")
	await _frames(3)

func _check_bloater_out_of_range()->void:
	var _bloater:Node2D = await _spawn("bloater_instance_resource.tres", 120.0)
	var _loop:BossAttackLoop = _bloater.get_node("BossAttackLoop")
	_loop.next_attack_time = 0.0
	var _jumped:bool = false
	for i:int in 60:
		await get_tree().physics_frame
		_keep_player()
		_jumped = _jumped || _loop.current != null
	check(!_jumped, "bloater does not jump while the player is out of range")
	_kill(_bloater)
	await _frames(3)
	_kill_scene("zombie.tscn")
	await _frames(3)

func _check_bloater_burst()->void:
	var _cleared:Array[bool] = [false]
	var _bloater:Node2D = await _spawn("bloater_instance_resource.tres", 48.0, func ()->void: _cleared[0] = true)
	var _health:HealthResource = _bloater.get_node("ResourceNode").get_resource("health")
	_health.hp = _health.max_hp * 0.4
	var _loop:BossAttackLoop = _bloater.get_node("BossAttackLoop")
	_loop.get_node("Jump").burst_chance = 1.0
	_loop.next_attack_time = 0.0
	var _zombies_before:int = _count_scene("zombie.tscn")
	# pooled on death, which resets health: latch the death instead
	var _died:Array[bool] = [false]
	_health.dead.connect(func ()->void: _died[0] = true, CONNECT_ONE_SHOT)
	for i:int in 150:
		await get_tree().physics_frame
		_keep_player()
		if _died[0]:
			break
	await _frames(5)
	var _released:int = _count_scene("zombie.tscn") - _zombies_before
	check(_died[0], "low health bloater bursts on landing")
	check(_released == 3, "burst releases 3 zombies (%d)" % _released)
	check(!_cleared[0], "burst bloater still counts while its zombies live")
	_kill_scene("zombie.tscn")
	await _frames(5)
	check(_cleared[0], "wave counts the bloater killed once its zombies die")

## Weapon wielder hits the player, its projectiles only mask the player and pass through a zombie in the way
func _check_wielder(id:String, projectile_scene:String, distance:float)->void:
	var _enemy:Node2D = await _spawn(id + "_instance_resource.tres", distance)
	var _weapon:Node = _enemy.get_node("SlashAttack")
	check(_weapon.collision_mask == 2, "%s weapon masks only the player" % id)
	var _bystander:Node2D = await _spawn("zomby_instance_resource.tres", distance * 0.5)
	_bystander.get_node("ZombieInput").set_enabled(false)
	_bystander.get_node("ZombieInput").process_mode = Node.PROCESS_MODE_DISABLED
	var _bystander_health:HealthResource = _bystander.get_node("ResourceNode").get_resource("health")
	var _bystander_hp:float = _bystander_health.hp
	var _hits_before:int = player_hits
	var _shots:int = 0
	var _bad_mask:int = 0
	for i:int in 240:
		await get_tree().physics_frame
		_keep_player()
		_enemy.global_position = _spot(distance)
		for _projectile:Node in _find_scene(projectile_scene):
			_shots += 1
			if _projectile.collision_mask != 2:
				_bad_mask = _projectile.collision_mask
	check(_shots > 0, "%s attacks the player" % id)
	check(_bad_mask == 0, "%s projectiles mask only the player (got %d)" % [id, _bad_mask])
	check(player_hits > _hits_before, "%s weapon damages the player" % id)
	check(is_equal_approx(_bystander_health.hp, _bystander_hp), "%s weapon never damages a zombie" % id)
	_kill(_enemy)
	_kill(_bystander)
	await _frames(5)

## Free spot `distance` away from the player, first direction with open floor all the way
func _spot(distance:float)->Vector2:
	for _angle:float in [0.0, PI, PI * 0.5, -PI * 0.5, PI * 0.25, PI * 0.75, -PI * 0.25, -PI * 0.75]:
		var _direction:Vector2 = Vector2.RIGHT.rotated(_angle)
		var _open:bool = true
		for _step:int in range(1, int((distance + 16.0) / 4.0)):
			var _cell:Vector2i = tilemap.local_to_map(tilemap.to_local(player.global_position + _direction * _step * 4.0))
			if !astar.region.has_point(_cell) || astar.is_point_solid(_cell):
				_open = false
				break
		if _open:
			return player.global_position + _direction * distance
	return player.global_position + Vector2.RIGHT * distance

func _spawn(resource_name:String, distance:float, clear_callback:Callable = Callable())->Node2D:
	var _position:Vector2 = _spot(distance)
	var _resource:InstanceResource = load(ACTORS + resource_name)
	var _enemy:Node2D = _resource.instance(func (inst:Node2D)->void:
		inst.global_position = _position
		if clear_callback.is_valid():
			ActiveEnemy.insert_child(inst, ActiveEnemy.root, func (_enemy:ActiveEnemy)->void: clear_callback.call())
	)
	await _frames(3)
	return _enemy

func _keep_player()->void:
	player_health.hp = player_health.max_hp

func _kill(enemy:Node2D)->void:
	if !is_instance_valid(enemy) || !enemy.is_inside_tree():
		return
	var _health:HealthResource = enemy.get_node("ResourceNode").get_resource("health")
	if !_health.is_dead:
		_health.insta_kill()

func _kill_scene(scene:String)->void:
	for _node:Node in _find_scene(scene):
		_kill(_node)

func _find_scene(scene:String)->Array[Node]:
	var _found:Array[Node]
	for _node:Node in get_tree().root.find_children("*", "", true, false):
		if _node.scene_file_path.ends_with("/" + scene) && _node.is_inside_tree():
			if _node.has_node("ResourceNode") && _node.get_node("ResourceNode").get_resource("health").is_dead:
				continue
			_found.append(_node)
	return _found

func _count_scene(scene:String)->int:
	return _find_scene(scene).size()

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().process_frame

func _finish()->void:
	print("enemy_overhaul_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
