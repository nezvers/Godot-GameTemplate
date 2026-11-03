## Marks the AStarGrid2D cells under a body's collision shapes as solid, so tile navigation
## paths around props that aren't tiles (contraptions, crates). The cells are freed again when
## the node leaves the tree or gets disabled, e.g. a hidden contraption with PROCESS_MODE_DISABLED.
class_name AstarShapeObstacle
extends Node

@export var astargrid_resource:AstarGridResource

## Its CollisionShape2D children give the blocked area
@export var body:CollisionObject2D

## Pixels the shapes grow by, about half an actor body. Every tile touching the grown shape is
## blocked, so actors walking between free cell centers don't brush the prop.
@export var clearance:float = 2.0

## How many obstacles block each cell, shared by every obstacle of the grid
const META_NAME:StringName = &"shape_obstacle_counts"

## Cells this node blocks. Cells already solid from walls are left out, so freeing never opens a wall.
var cells:Array[Vector2i]

## The grid the cells belong to
var grid:AStarGrid2D

func _ready()->void:
	assert(astargrid_resource != null)
	assert(body != null)
	if !astargrid_resource.updated.is_connected(_on_grid_updated):
		astargrid_resource.updated.connect(_on_grid_updated)
		astargrid_resource.cleanup_event.connect(_on_grid_cleanup)
	# deferred after the wall layers' TileAstargridObstacle (earlier in the tree), so wall cells are
	# already solid and stay out of cells
	apply.call_deferred()

## Re-entering the tree (not the first time, _ready covers that)
func _enter_tree()->void:
	if is_node_ready():
		apply.call_deferred()

func _exit_tree()->void:
	release()

func _notification(what:int)->void:
	match what:
		NOTIFICATION_DISABLED:
			release()
		NOTIFICATION_ENABLED:
			apply.call_deferred()

## Blocks the cells under the body, does nothing when already applied or disabled
func apply()->void:
	var _astar:AStarGrid2D = astargrid_resource.value
	if _astar == null || !cells.is_empty() || !is_inside_tree() || !can_process():
		return
	var _counts:Dictionary = _get_counts(_astar)
	for _cell:Vector2i in covered_cells():
		if !_astar.region.has_point(_cell):
			continue
		var _count:int = _counts.get(_cell, 0)
		if _count == 0 && _astar.is_point_solid(_cell):
			continue
		_counts[_cell] = _count + 1
		_astar.set_point_solid(_cell, true)
		cells.append(_cell)
	grid = _astar

## Frees the cells no other obstacle still blocks
func release()->void:
	var _astar:AStarGrid2D = astargrid_resource.value
	if _astar == null || _astar != grid:
		cells.clear()
		return
	var _counts:Dictionary = _get_counts(_astar)
	for _cell:Vector2i in cells:
		var _count:int = _counts.get(_cell, 1) - 1
		if _count > 0:
			_counts[_cell] = _count
			continue
		_counts.erase(_cell)
		_astar.set_point_solid(_cell, false)
	cells.clear()

## Grid cells whose tile overlaps a shape's bounding box grown by clearance
func covered_cells()->Array[Vector2i]:
	var _result:Array[Vector2i]
	var _tilemap:TileMapLayer = astargrid_resource.tilemap_layer
	var _half:Vector2 = Vector2(_tilemap.tile_set.tile_size) * 0.5
	var _tile:PackedVector2Array = [Vector2(0, -_half.y), Vector2(_half.x, 0), Vector2(0, _half.y), Vector2(-_half.x, 0)]
	for _child:Node in body.get_children():
		var _shape_node:CollisionShape2D = _child as CollisionShape2D
		if _shape_node == null || _shape_node.shape == null || _shape_node.disabled:
			continue
		var _rect:Rect2 = _shape_node.global_transform * _shape_node.shape.get_rect()
		_rect = _tilemap.get_global_transform().affine_inverse() * _rect.grow(clearance)
		var _rect_polygon:PackedVector2Array = [_rect.position, Vector2(_rect.end.x, _rect.position.y), _rect.end, Vector2(_rect.position.x, _rect.end.y)]
		# map coords are linear in position, so the corners' cells bound every overlapped cell
		var _min:Vector2i = _tilemap.local_to_map(_rect.position)
		var _max:Vector2i = _min
		for _point:Vector2 in _rect_polygon:
			_min = _min.min(_tilemap.local_to_map(_point))
			_max = _max.max(_tilemap.local_to_map(_point))
		for _x:int in range(_min.x, _max.x + 1):
			for _y:int in range(_min.y, _max.y + 1):
				var _cell:Vector2i = Vector2i(_x, _y)
				if _result.has(_cell):
					continue
				var _diamond:PackedVector2Array = Transform2D(0.0, _tilemap.map_to_local(_cell)) * _tile
				if !Geometry2D.intersect_polygons(_diamond, _rect_polygon).is_empty():
					_result.append(_cell)
	return _result

func _get_counts(astar:AStarGrid2D)->Dictionary:
	if !astar.has_meta(META_NAME):
		astar.set_meta(META_NAME, {})
	return astar.get_meta(META_NAME)

## A new grid starts with every cell free
func _on_grid_updated()->void:
	if astargrid_resource.value != grid:
		cells.clear()
	apply()

func _on_grid_cleanup()->void:
	cells.clear()
