## Enemies path around room contraptions: their cells are solid in the AStarGrid2D without cutting
## off any floor, paths keep clear of their bodies, a zombie walks around one to reach the player,
## and a hidden workbench leaves its cells free.
##   Godot --headless --path . res://game/tests/obstacle_path_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
## Rooms with contraptions: the hand-made test room and campaign side rooms
const ROOMS:Array[String] = ["room_A02", "room_N02", "room_N21", "room_P01", "room_P21"]

var failures:int = 0
var checks:int = 0

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	var _slime:ScoreResource = load(TD + "resources/global_resources/slime_resource.tres")
	_slime.reset_resource()
	for _room_name:String in ROOMS:
		var _room:Node = (load("res://game/scenes/%s.tscn" % _room_name) as PackedScene).instantiate()
		add_child(_room)
		await _frames(10)
		await _check_room(_room_name, _room)
		_room.queue_free()
		await _frames(3)
	_finish()

func _check_room(room_name:String, room:Node)->void:
	var _slime:ScoreResource = load(TD + "resources/global_resources/slime_resource.tres")
	var _grid_resource:AstarGridResource = load(TD + "resources/arena_resources/obstacle_astargrid_resource.tres")
	var _astar:AStarGrid2D = _grid_resource.value
	var _tilemap:TileMapLayer = _grid_resource.tilemap_layer
	var _player:Node2D = (load(TD + "resources/ReferenceNodeResources/player_reference.tres") as ReferenceNodeResource).node
	check(_astar != null && _player != null, "%s grid and player ready" % room_name)
	if _astar == null || _player == null:
		return
	var _props:Array[Node2D]
	for _child:Node in room.get_node("WallLayer_Ysorted").get_children():
		if _child.has_node("AstarShapeObstacle"):
			_props.append(_child)
	check(!_props.is_empty(), "%s has contraptions" % room_name)

	_slime.reset_resource()
	await _frames(3)
	for _prop:Node2D in _props:
		if _prop.get_script().get_global_name() == &"SlimeWorkbench":
			check(_prop.get_node("AstarShapeObstacle").cells.is_empty(), "%s hidden %s leaves its cells free" % [room_name, _prop.name])
	_slime.add(2)
	await _frames(3)

	var _blocked:Array[Vector2i]
	for _prop:Node2D in _props:
		var _cells:Array[Vector2i] = _prop.get_node("AstarShapeObstacle").cells
		check(!_cells.is_empty() && _cells.size() <= 8, "%s %s blocks a few cells (%d)" % [room_name, _prop.name, _cells.size()])
		_blocked.append_array(_cells)
	_check_connected(room_name, _astar, _blocked)

	var _chased:int = 0
	for _prop:Node2D in _props:
		var _cell:Vector2i = _tilemap.local_to_map(_tilemap.to_local(_prop.global_position))
		var _rect:Rect2 = _body_rect(_prop)
		var _pairs:Array[Array] = _opposite_spots(_rect, _cell, _astar, _tilemap)
		for _pair:Array in _pairs:
			var _path:PackedVector2Array = _astar.get_point_path(_tilemap.local_to_map(_pair[0]), _tilemap.local_to_map(_pair[1]))
			check(_path_clearance(_path, _rect) >= 2.0, "%s %s path %s keeps clear of the body (%.1f px)" % [room_name, _prop.name, _pair, _path_clearance(_path, _rect)])
		if _pairs.is_empty():
			# against a wall, nothing to walk around
			continue
		# zombie on one side, player on the other: the zombie has to walk around
		var _reached:float = await _chase(_pairs[0][0], _pairs[0][1], _player)
		check(_reached < 16.0, "%s zombie walks around %s to the player (closest %.1f px)" % [room_name, _prop.name, _reached])
		_chased += 1
	check(_chased > 0, "%s has a contraption to walk around" % room_name)

## The blocked cells never split the room's floor: free cells that were connected without them stay connected
func _check_connected(room_name:String, astar:AStarGrid2D, blocked:Array[Vector2i])->void:
	for _cell:Vector2i in blocked:
		astar.set_point_solid(_cell, false)
	var _open:Dictionary = _components(astar, {})
	for _cell:Vector2i in blocked:
		astar.set_point_solid(_cell, true)
	var _closed:Dictionary = _components(astar, {})
	# every open component must stay one closed component
	var _seen:Dictionary = {}
	var _splits:int = 0
	for _cell:Vector2i in _closed:
		var _before:int = _open[_cell]
		if _seen.has(_before) && _seen[_before] != _closed[_cell]:
			_splits += 1
		_seen[_before] = _closed[_cell]
	check(_splits == 0, "%s contraptions don't cut off floor (%d cells)" % [room_name, _splits])

## Component label of every free cell, side neighbours only (diagonals need both sides free anyway)
func _components(astar:AStarGrid2D, labels:Dictionary)->Dictionary:
	var _region:Rect2i = astar.region
	var _label:int = 0
	for _x:int in range(_region.position.x, _region.end.x):
		for _y:int in range(_region.position.y, _region.end.y):
			var _start:Vector2i = Vector2i(_x, _y)
			if labels.has(_start) || astar.is_point_solid(_start):
				continue
			_label += 1
			var _stack:Array[Vector2i] = [_start]
			labels[_start] = _label
			while !_stack.is_empty():
				var _cell:Vector2i = _stack.pop_back()
				for _step:Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var _next:Vector2i = _cell + _step
					if _region.has_point(_next) && !labels.has(_next) && !astar.is_point_solid(_next):
						labels[_next] = _label
						_stack.append(_next)
	return labels

## Pairs of free cell centers (tilemap at the origin) whose straight line crosses the body
func _opposite_spots(rect:Rect2, cell:Vector2i, astar:AStarGrid2D, tilemap:TileMapLayer)->Array[Array]:
	var _free:Array[Vector2]
	for _x:int in range(-3, 4):
		for _y:int in range(-3, 4):
			var _cell:Vector2i = cell + Vector2i(_x, _y)
			if astar.region.has_point(_cell) && !astar.is_point_solid(_cell):
				_free.append(tilemap.map_to_local(_cell))
	var _pairs:Array[Array]
	for i:int in _free.size():
		for j:int in range(i + 1, _free.size()):
			var _distance:float = _free[i].distance_to(_free[j])
			if _distance < 40.0 || _distance > 72.0 || _path_clearance([_free[i], _free[j]], rect) > 0.0:
				continue
			# the player must be reachable at all
			if astar.get_id_path(tilemap.local_to_map(_free[i]), tilemap.local_to_map(_free[j])).is_empty():
				continue
			_pairs.append([_free[i], _free[j]])
	return _pairs

## Closest distance a zombie starting at zombie_spot gets to the player held at player_spot
func _chase(zombie_spot:Vector2, player_spot:Vector2, player:Node2D)->float:
	# the player stands still, so keep it alive through the zombie's hits
	var _health:HealthResource = player.get_node("ResourceNode").get_resource("health")
	player.global_position = player_spot
	await _frames(2)
	var _zombie_resource:InstanceResource = load(TD + "resources/InstanceResources/actors/zomby_instance_resource.tres")
	var _zombie:Node2D = _zombie_resource.instance(func (inst:Node2D)->void: inst.global_position = zombie_spot)
	var _closest:float = INF
	for i:int in 360:
		await get_tree().physics_frame
		player.global_position = player_spot
		_health.hp = _health.max_hp
		_closest = minf(_closest, _zombie.global_position.distance_to(player_spot))
	_zombie.queue_free()
	await _frames(2)
	return _closest

func _body_rect(prop:Node2D)->Rect2:
	var _shape:CollisionShape2D = prop.get_node("StaticBody2D/CollisionShape2D")
	return _shape.global_transform * _shape.shape.get_rect()

## Smallest distance between the path's segments and rect
func _path_clearance(path:PackedVector2Array, rect:Rect2)->float:
	var _closest:float = INF
	for i:int in path.size() - 1:
		for t:int in 21:
			var _point:Vector2 = path[i].lerp(path[i + 1], t / 20.0)
			var _inside:Vector2 = _point.clamp(rect.position, rect.end)
			_closest = minf(_closest, _point.distance_to(_inside))
	return _closest

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().process_frame

func _finish()->void:
	print("obstacle_path_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
