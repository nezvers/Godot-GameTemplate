class_name FixSpawnOverlap
extends ShapeCast2D

@export var character_body:CharacterBody2D

@export var collision_shape:CollisionShape2D

@export var move_distance:float = 8.0

func _ready()->void:
	position = collision_shape.position
	shape = collision_shape.shape
	enabled = false
	target_position = Vector2.ZERO
	collision_mask = character_body.collision_mask
	tree_entered.connect(_fix)
	_fix()

func _fix(remaining:int = 16)->void:
	force_shapecast_update()
	var _colision_count:int = get_collision_count()
	if _colision_count == 0:
		return
	var average_normal:Vector2
	for i:int in _colision_count:
		average_normal += get_collision_normal(i)
		
	average_normal = average_normal.normalized()
	character_body.global_position += average_normal * move_distance
	if remaining < 1:
		return
	_fix(remaining -1)
