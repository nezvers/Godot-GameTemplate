## Navigation for a large actor that walks over wall groups no bigger than max_size tiles
## and over holes no thicker than max_thickness tiles (any length), while room walls and bigger groups still block it.
## Groups are found once per room from the TileCollisionGenerator colliders. Their colliders move
## to a "StraddleBody" next to the original body, with the same layers, so only this actor ignores them.
class_name StraddleNavigationGetter
extends TileNavigationGetter

## Actor body that stops colliding with small groups
@export var body:PhysicsBody2D

## Line of sight check that sees through small groups
@export var raycast:RayCast2D

## MoverTopDown2D pushes out of overlapping solids, it has to ignore small groups too
@export var mover:ShapeCast2D

## Wall groups fitting in this many tiles are crossed
@export var max_size:Vector2i = Vector2i(2, 2)

## Holes (colliders the body doesn't collide with) are crossed when no thicker than this many tiles
@export var max_thickness:int = 2

const META_NAME:StringName = &"straddle_cells"

## Small group tiles, opened in the AStarGrid2D while calculating a path
var open_cells:Array[Vector2i]

func _ready()->void:
	super._ready()
	# colliders are moved outside physics callbacks
	_setup.call_deferred()

func get_target_path(to:Vector2)->PackedVector2Array:
	var _astar:AStarGrid2D = astargrid_resource.value
	var _opened:Array[Vector2i]
	for _cell:Vector2i in open_cells:
		if _astar.region.has_point(_cell) && _astar.is_point_solid(_cell):
			_astar.set_point_solid(_cell, false)
			_opened.append(_cell)
	super.get_target_path(to)
	for _cell:Vector2i in _opened:
		_astar.set_point_solid(_cell, true)
	return navigation_path

func _setup()->void:
	open_cells.clear()
	var _astar:AStarGrid2D = astargrid_resource.value
	if _astar == null || !is_inside_tree():
		return
	# first straddler in the room splits colliders, others reuse the result
	if !_astar.has_meta(META_NAME):
		_astar.set_meta(META_NAME, _split_small_groups())
	var _data:Dictionary = _astar.get_meta(META_NAME)
	open_cells = _data.cells
	for _straddle_body:StaticBody2D in _data.bodies:
		if !is_instance_valid(_straddle_body):
			continue
		body.add_collision_exception_with(_straddle_body)
		if raycast != null:
			raycast.add_exception(_straddle_body)
		if mover != null:
			mover.add_exception(_straddle_body)

func _split_small_groups()->Dictionary:
	var _generators:Array[TileCollisionGenerator]
	_collect_generators(get_tree().root, _generators)

	var _cells:Array[Vector2i]
	var _bodies:Array[StaticBody2D]
	# walls and holes are grouped separately, a hole next to a wall stays crossable
	for _generator:TileCollisionGenerator in _generators:
		var _source:StaticBody2D = _generator.static_body
		if _source == null || _generator.tilemap_layer == null:
			continue
		# body doesn't collide with holes, they only block navigation
		var _is_hole:bool = (_source.collision_layer & body.collision_mask) == 0
		# collider per tile
		var _colliders:Dictionary[Vector2i, Array]
		for _child:Node in _source.get_children():
			if !(_child is CollisionPolygon2D):
				continue
			var _cell:Vector2i = _generator.tilemap_layer.local_to_map(_child.position)
			if !_colliders.has(_cell):
				_colliders[_cell] = []
			_colliders[_cell].append(_child)

		var _straddle_body:StaticBody2D = null
		for _group:Array[Vector2i] in _find_groups(_colliders.keys()):
			if _is_hole && !_is_thin(_group):
				continue
			if !_is_hole && !_is_small(_group):
				continue
			if _straddle_body == null:
				_straddle_body = _create_straddle_body(_source)
				_bodies.append(_straddle_body)
			_cells.append_array(_group)
			for _cell:Vector2i in _group:
				for _collider:CollisionPolygon2D in _colliders[_cell]:
					_collider.reparent(_straddle_body)
	return {cells = _cells, bodies = _bodies}

func _collect_generators(node:Node, list:Array[TileCollisionGenerator])->void:
	if node is TileCollisionGenerator:
		list.append(node)
	for _child:Node in node.get_children():
		_collect_generators(_child, list)

## Groups of tiles touching each other, diagonals included
func _find_groups(cell_list:Array)->Array[Array]:
	var _left:Dictionary[Vector2i, bool]
	for _cell:Vector2i in cell_list:
		_left[_cell] = true
	var _groups:Array[Array]
	while !_left.is_empty():
		var _start:Vector2i = _left.keys()[0]
		_left.erase(_start)
		var _group:Array[Vector2i] = [_start]
		var i:int = 0
		while i < _group.size():
			for x:int in range(-1, 2):
				for y:int in range(-1, 2):
					var _next:Vector2i = _group[i] + Vector2i(x, y)
					if _left.has(_next):
						_left.erase(_next)
						_group.append(_next)
			i += 1
		_groups.append(_group)
	return _groups

func _is_small(group:Array[Vector2i])->bool:
	var _min:Vector2i = group[0]
	var _max:Vector2i = group[0]
	for _cell:Vector2i in group:
		_min = _min.min(_cell)
		_max = _max.max(_cell)
	var _size:Vector2i = _max - _min + Vector2i.ONE
	return _size.x <= max_size.x && _size.y <= max_size.y

## No filled square of max_thickness + 1 tiles fits in the group
func _is_thin(group:Array[Vector2i])->bool:
	var _lookup:Dictionary[Vector2i, bool]
	for _cell:Vector2i in group:
		_lookup[_cell] = true
	var _side:int = max_thickness + 1
	for _cell:Vector2i in group:
		var _filled:bool = true
		for x:int in _side:
			for y:int in _side:
				if !_lookup.has(_cell + Vector2i(x, y)):
					_filled = false
		if _filled:
			return false
	return true

func _create_straddle_body(source:StaticBody2D)->StaticBody2D:
	var _straddle_body:StaticBody2D = StaticBody2D.new()
	_straddle_body.name = source.name + "Straddle"
	_straddle_body.collision_layer = source.collision_layer
	_straddle_body.collision_mask = source.collision_mask
	_straddle_body.z_index = source.z_index
	source.add_sibling(_straddle_body)
	_straddle_body.global_transform = source.global_transform
	return _straddle_body
