extends Node

@export var character_body:CharacterBody2D
@export var collision_shape:CollisionShape2D
## Blends between bounce and slide against a surface
@export_range(0.0, 1.0) var bounciness:float
## Minimal dot product value to blend between bounce
@export_range(0.01, 1.0) var slide_treshold:float
## Maximal movement itteration count from collisions
@export var max_steps:int = 10

var shape_cast:ShapeCast2D = ShapeCast2D.new()

func _ready()->void:
	shape_cast.exclude_parent = true
	shape_cast.shape = collision_shape.shape
	shape_cast.enabled = false
	shape_cast.collision_mask = character_body.collision_mask
	character_body.add_child.call_deferred(shape_cast)

func move(vector:Vector2)-> Vector2:
	for i:int in max_steps:
		shape_cast.target_position = vector
		shape_cast.force_shapecast_update()
		if !shape_cast.is_colliding():
			character_body.global_position += vector
			return vector
		var _fraction:float = shape_cast.get_closest_collision_safe_fraction()
		var _moved:Vector2 = vector * _fraction
		character_body.global_position += _moved
		vector = vector - _moved
		
		# TODO: check if is pushable object and interact with it
		var _normal:Vector2 = shape_cast.get_collision_normal(0)
		var _dot_product:float = _normal.dot(-vector.normalized())
		if _dot_product < slide_treshold:
			vector = vector.bounce(_normal)
			continue
		
		var _bounce = vector.bounce(_normal)
		var _slide = vector.slide(_normal)
		vector = _slide.lerp(_bounce, bounciness)
	return vector
