## Helper node to move out of solid colliders
class_name FixSpawnOverlap
extends ShapeCast2D

@export var move_node:Node2D

var extent:Vector2

func _ready()->void:
	enabled = false
	target_position = Vector2.ZERO
	extent = shape.get_rect().size * 0.5
	_fix()
	request_ready()

func _fix()->void:
	if !is_colliding():
		return
	var _solid_distance:Vector2
	var _count:int = get_collision_count()
	if _count < 1:
		return
	for i:int in _count:
		var _point:Vector2 = get_collision_point(i)
		var _collider:Object = get_collider(i)
		_solid_distance += _rect_distance(global_position - _point)
	move_node.global_position += _solid_distance


func _rect_distance(distance:Vector2)->Vector2:
	distance.x = sign(distance.x) * extent.x - distance.x
	distance.y = sign(distance.y) * extent.y - distance.y
	return distance
