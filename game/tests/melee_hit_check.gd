## Melee hits and crowd separation: one katana slash cleaves through a pack of small slimes (each hit once),
## a resting pack stays still, a kicked slime does not pop its neighbours, stacked spawns separate smoothly.
##   Godot --headless --path . res://game/tests/melee_hit_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const ROOM:String = "res://game/scenes/room_A02.tscn"
const SLIME:String = TD + "resources/InstanceResources/actors/slime_small_instance_resource.tres"
const SLASH:String = TD + "resources/InstanceResources/projectiles/sword_slash_instance_resource.tres"
## Enemy layer
const ENEMY_MASK:int = 4

var failures:int = 0
var checks:int = 0
var player:Node2D
var player_health:HealthResource
var astar:AStarGrid2D
var tilemap:TileMapLayer
## Open floor away from the player, the pack is built around it
var center:Vector2
## Largest move during the last _spawn_all frames
var spawn_jump:float

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
	center = _open_spot()
	check(center != Vector2.INF, "found open floor for the pack")
	if center == Vector2.INF:
		_finish()
		return

	await _check_resting_pack()
	await _check_cleave()
	await _check_kicked_pack()
	await _check_stacked_spawn()
	await _check_chasing_crowd()
	await _check_wall_kick()
	_finish()

## One slash through 5 slimes standing in its path
func _check_cleave()->void:
	var _slimes:Array[Node2D] = await _spawn_all([
		Vector2(14, -3), Vector2(14, 3), Vector2(21, -3), Vector2(21, 3), Vector2(27, 0)])
	var _hits:Dictionary = {}
	for _slime:Node2D in _slimes:
		var _health:HealthResource = _health_of(_slime)
		_health.damaged.connect(func ()->void: _hits[_slime] = _hits.get(_slime, 0) + 1)
	_fire_slash(center, Vector2.RIGHT)
	for i:int in 30:
		await get_tree().physics_frame
	var _repeat:int = 0
	for _count:int in _hits.values():
		if _count > 1:
			_repeat += 1
	check(_hits.size() >= 4, "one slash hits most of the pack (%d of 5)" % _hits.size())
	check(_repeat == 0, "a slash hits each slime once (%s)" % [_hits.values()])
	_kill_all(_slimes)
	await _frames(5)

## Touching slimes with no input never move
func _check_resting_pack()->void:
	var _slimes:Array[Node2D] = await _spawn_all(_grid_offsets(3, 2, Vector2(6.02, 3.02)))
	var _jump:float = maxf(spawn_jump, await _max_step(_slimes, 60))
	check(_jump < 0.3, "resting pack stays still (max step %.2f px)" % _jump)
	_kill_all(_slimes)
	await _frames(5)

## A sword sized kick into a pack: neighbours are shoved, never teleported
func _check_kicked_pack()->void:
	var _slimes:Array[Node2D] = await _spawn_all(_grid_offsets(4, 3, Vector2(6.02, 3.02)))
	await _settle()
	var _kicked:Node2D = _slimes[4]
	_kicked.get_node("ResourceNode").get_resource("push").add_impulse(Vector2.RIGHT * 100.0)
	var _bystanders:Array[Node2D] = _slimes.duplicate()
	_bystanders.erase(_kicked)
	var _jump:float = await _max_step(_bystanders, 40)
	check(_jump < 2.0, "kick does not pop neighbours (max step %.2f px)" % _jump)
	check(_overlaps(_slimes) == 0, "kicked pack ends without overlaps (%d)" % _overlaps(_slimes))
	_kill_all(_slimes)
	await _frames(5)

## Spawned on one spot, like split children
func _check_stacked_spawn()->void:
	var _slimes:Array[Node2D] = await _spawn_all([Vector2.ZERO, Vector2.ZERO, Vector2(0.5, 0.2)])
	var _jump:float = maxf(spawn_jump, await _max_step(_slimes, 40))
	check(_jump < 2.0, "stacked slimes separate smoothly (max step %.2f px)" % _jump)
	check(_overlaps(_slimes) == 0, "stacked slimes end apart (%d overlaps)" % _overlaps(_slimes))
	_kill_all(_slimes)
	await _frames(5)

## Slimes crowding the player while one after another gets kicked: nobody but the kicked one moves faster than walking
func _check_chasing_crowd()->void:
	var _slimes:Array[Node2D] = await _spawn_all(_grid_offsets(4, 3, Vector2(7.0, 4.0)), false)
	var _last:Array[Vector2]
	for _slime:Node2D in _slimes:
		_last.append(_slime.global_position)
	var _kicked_until:Dictionary = {}
	var _jump:float = 0.0
	for i:int in 240:
		# the pack walks into the player, which stands still
		player.global_position = center + Vector2(-40, 6)
		if i >= 60 && i % 12 == 0:
			var _target:Node2D = _slimes[(i / 12) % _slimes.size()]
			var _away:Vector2 = (_target.global_position - player.global_position).normalized()
			_target.get_node("ResourceNode").get_resource("push").add_impulse(_away * 100.0)
			_kicked_until[_target] = i + 12
		await get_tree().physics_frame
		player_health.hp = player_health.max_hp
		for j:int in _slimes.size():
			if _kicked_until.get(_slimes[j], -1) < i:
				_jump = maxf(_jump, _slimes[j].global_position.distance_to(_last[j]))
			_last[j] = _slimes[j].global_position
	check(_jump < 1.5, "crowd being hit moves no faster than walking (max step %.2f px)" % _jump)
	_kill_all(_slimes)
	await _frames(5)

## Kicked against a wall: stays out of it, no sideways jump
func _check_wall_kick()->void:
	var _wall:Array = _wall_spot()
	check(!_wall.is_empty(), "found a wall to kick into")
	if _wall.is_empty():
		return
	var _start:Vector2 = _wall[0]
	var _direction:Vector2 = _wall[1]
	var _slime:Node2D = (await _spawn_all([_start - center]))[0]
	_slime.get_node("ResourceNode").get_resource("push").add_impulse(_direction * 160.0)
	var _jump:float = 0.0
	var _inside:bool = false
	var _last:Vector2 = _slime.global_position
	for i:int in 40:
		await get_tree().physics_frame
		var _step:Vector2 = _slime.global_position - _last
		_last = _slime.global_position
		# sideways to the kick
		_jump = maxf(_jump, absf(_step.dot(_direction.orthogonal())))
		_inside = _inside || _in_solid(_slime)
	check(_jump < 2.0, "wall kick has no sideways pop (max %.2f px)" % _jump)
	check(!_inside, "kicked slime never ends inside a wall")
	_kill_all([_slime])
	await _frames(5)

func _fire_slash(from:Vector2, direction:Vector2)->Node2D:
	var _damage:DamageDataResource = DamageDataResource.new("damage")
	_damage.critical_chance = 0.0
	var _resource:InstanceResource = load(SLASH)
	return _resource.instance(func (inst:Projectile2D)->void:
		inst.direction = direction
		inst.damage_data_resource = _damage.new_generation()
		inst.collision_mask = Bitwise.append_flags(inst.collision_mask, ENEMY_MASK)
		inst.global_position = from + direction * 10.0
	)

## Spawn pops count too: steps are measured from the spawn spot on
func _spawn_all(offsets:Array, frozen:bool = true)->Array[Node2D]:
	var _resource:InstanceResource = load(SLIME)
	var _slimes:Array[Node2D]
	var _last:Array[Vector2]
	for _offset:Vector2 in offsets:
		var _position:Vector2 = center + _offset
		_slimes.append(_resource.instance(func (inst:Node2D)->void: inst.global_position = _position))
		_last.append(_position)
	spawn_jump = 0.0
	for i:int in 3:
		await get_tree().physics_frame
		for j:int in _slimes.size():
			spawn_jump = maxf(spawn_jump, _slimes[j].global_position.distance_to(_last[j]))
			_last[j] = _slimes[j].global_position
	for _slime:Node2D in _slimes:
		if frozen:
			var _input:Node = _slime.get_node("ZombieInput")
			_input.set_enabled(false)
			_input.process_mode = Node.PROCESS_MODE_DISABLED
			_slime.get_node("ResourceNode").get_resource("input").axis = Vector2.ZERO
		var _health:HealthResource = _health_of(_slime)
		_health.max_hp = 1000.0
		_health.hp = 1000.0
	return _slimes

func _grid_offsets(columns:int, rows:int, spacing:Vector2)->Array:
	var _offsets:Array
	for y:int in rows:
		for x:int in columns:
			_offsets.append(Vector2(x, y) * spacing)
	return _offsets

## Lets spawn overlap fixes finish before measuring
func _settle()->void:
	for i:int in 20:
		await get_tree().physics_frame

## Largest single physics frame move of any of the bodies
func _max_step(bodies:Array[Node2D], frames:int)->float:
	var _last:Array[Vector2]
	for _body:Node2D in bodies:
		_last.append(_body.global_position)
	var _max:float = 0.0
	for i:int in frames:
		await get_tree().physics_frame
		player_health.hp = player_health.max_hp
		for j:int in bodies.size():
			_max = maxf(_max, bodies[j].global_position.distance_to(_last[j]))
			_last[j] = bodies[j].global_position
	return _max

## Pairs whose body rects overlap by more than a hair
func _overlaps(bodies:Array[Node2D])->int:
	var _count:int = 0
	for i:int in bodies.size():
		for j:int in range(i + 1, bodies.size()):
			if _rect(bodies[i]).grow(-0.1).intersects(_rect(bodies[j]).grow(-0.1)):
				_count += 1
	return _count

func _rect(body:Node2D)->Rect2:
	var _shape:CollisionShape2D = body.get_node("CollisionShape2D")
	var _size:Vector2 = (_shape.shape as RectangleShape2D).size
	return Rect2(_shape.global_position - _size * 0.5, _size)

func _health_of(body:Node2D)->HealthResource:
	return body.get_node("ResourceNode").get_resource("health")

func _kill_all(bodies:Array)->void:
	for _body:Node2D in bodies:
		if !is_instance_valid(_body) || !_body.is_inside_tree():
			continue
		var _health:HealthResource = _health_of(_body)
		if !_health.is_dead:
			_health.insta_kill()

## Open floor at least 64 px from the player with room for a 4x3 pack and the slash path
func _open_spot()->Vector2:
	var _origin:Vector2i = tilemap.local_to_map(tilemap.to_local(player.global_position))
	for _radius:int in range(4, 20):
		for _dx:int in range(-_radius, _radius + 1):
			for _dy:int in [-_radius, _radius]:
				var _cell:Vector2i = _origin + Vector2i(_dx, _dy)
				var _position:Vector2 = tilemap.to_global(tilemap.map_to_local(_cell))
				if _position.distance_to(player.global_position) < 64.0:
					continue
				if _area_open(_position + Vector2(-8, -12), _position + Vector2(48, 20)):
					return _position
	return Vector2.INF

func _area_open(from:Vector2, to:Vector2)->bool:
	var _y:float = from.y
	while _y <= to.y:
		var _x:float = from.x
		while _x <= to.x:
			if !_open(Vector2(_x, _y)):
				return false
			_x += 4.0
		_y += 4.0
	return true

func _open(position:Vector2)->bool:
	var _cell:Vector2i = tilemap.local_to_map(tilemap.to_local(position))
	return astar.region.has_point(_cell) && !astar.is_point_solid(_cell)

## Body shape (shrunk a hair, touching is fine) overlaps level collision
func _in_solid(body:CharacterBody2D)->bool:
	var _shape:CollisionShape2D = body.get_node("CollisionShape2D")
	var _box:RectangleShape2D = RectangleShape2D.new()
	_box.size = (_shape.shape as RectangleShape2D).size - Vector2(0.4, 0.4)
	var _query:PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	_query.shape = _box
	_query.transform = _shape.global_transform
	_query.collision_mask = 1
	_query.exclude = [body.get_rid()]
	return !get_viewport().world_2d.direct_space_state.intersect_shape(_query, 1).is_empty()

## Open spot 12 px from a solid cell, and the direction toward it
func _wall_spot()->Array:
	for _direction:Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var _position:Vector2 = center
		for _step:int in 80:
			var _next:Vector2 = _position + _direction * 2.0
			if !_open(_next):
				var _start:Vector2 = _position - _direction * 12.0
				if _open(_start) && _open(_start + _direction.orthogonal() * 6.0) && _open(_start - _direction.orthogonal() * 6.0):
					return [_start, _direction]
				break
			_position = _next
	return []

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().process_frame

func _finish()->void:
	print("melee_hit_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
