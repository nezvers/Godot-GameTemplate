## Where the current room's holes are: the shapes of its HoleTransmission areas
## (hole_obstacle tiles), in global space. Holes never move, so they're gathered
## once per room. Used to keep jumps from landing in one (BossJump).
class_name HoleMap
extends RefCounted

## Room instance id the cache belongs to
static var _room_id:int
## Global hole polygons and their bounding boxes (same order)
static var _polygons:Array[PackedVector2Array]
static var _bounds:Array[Rect2]

## Global hole polygons of the current room.
static func polygons(tree:SceneTree)->Array[PackedVector2Array]:
	_refresh(tree)
	return _polygons

## True when `shape` (a global polygon) touches any hole.
static func overlaps(tree:SceneTree, shape:PackedVector2Array)->bool:
	_refresh(tree)
	if shape.is_empty():
		return false
	var _box:Rect2 = Rect2(shape[0], Vector2.ZERO)
	for _point:Vector2 in shape:
		_box = _box.expand(_point)
	for _i:int in _polygons.size():
		if !_bounds[_i].intersects(_box, true):
			continue
		if !Geometry2D.intersect_polygons(shape, _polygons[_i]).is_empty():
			return true
	return false

## Drops the cache (a test that adds holes at runtime).
static func clear()->void:
	_room_id = 0
	_polygons.clear()
	_bounds.clear()

static func _refresh(tree:SceneTree)->void:
	var _room:Node = tree.current_scene if tree != null else null
	var _id:int = _room.get_instance_id() if _room != null else 0
	if _id == _room_id && _id != 0:
		return
	clear()
	_room_id = _id
	if _room == null:
		return
	for _node:Node in _room.find_children("*", "DataChannelTransmitter", true, false):
		var _transmitter:DataChannelTransmitter = _node
		if !(_transmitter.transmission_resource is HoleTransmission):
			continue
		var _area:Node = _transmitter.get_parent()
		for _child:Node in _area.get_children():
			if !(_child is CollisionPolygon2D):
				continue
			var _collision:CollisionPolygon2D = _child
			var _global:PackedVector2Array = _collision.global_transform * _collision.polygon
			if _global.size() < 3:
				continue
			var _box:Rect2 = Rect2(_global[0], Vector2.ZERO)
			for _point:Vector2 in _global:
				_box = _box.expand(_point)
			_polygons.append(_global)
			_bounds.append(_box)
