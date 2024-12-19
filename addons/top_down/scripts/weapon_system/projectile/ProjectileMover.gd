class_name ProjectileMover
extends Node

signal bounces_finished
signal bounce_position

@export var projectile:Projectile2D

## Check collision against these flags
@export_flags_2d_physics var collision_mask:int

enum MovementType {PROJECTILE, SHAPECAST, RAYCAST, LERP}
@export var movement_type:MovementType

## Allowed bounce count before destroyed
@export var max_bounce:int

@export var collision_shape:Shape2D

## Counter for allowed bounces before destroyed
var remaining_bounces:int

var move_direction:Vector2
var shape_cast:ShapeCast2D

var world_2d:World2D
var ray_query:PhysicsRayQueryParameters2D

func _get_configuration_warnings() -> PackedStringArray:
	var _warnings:PackedStringArray = PackedStringArray()
	if collision_shape == null && movement_type == MovementType.SHAPECAST:
		_warnings.append("Shapecast requires a collision shape")
	return _warnings

func _ready()->void:
	move_direction = _to_local_direction(projectile.direction).normalized()
	
	remaining_bounces = max(max_bounce, 0) + 1
	set_physics_process(true)
	
	match movement_type:
		MovementType.PROJECTILE:
			pass
		MovementType.SHAPECAST:
			if shape_cast == null:
				shape_cast = ShapeCast2D.new()
				shape_cast.shape = collision_shape
				shape_cast.collision_mask = collision_mask
				shape_cast.enabled = false
				projectile.add_child.call_deferred(shape_cast)
		MovementType.RAYCAST:
			world_2d = projectile.get_world_2d()
			if ray_query == null:
				ray_query = PhysicsRayQueryParameters2D.new()
				ray_query.collide_with_bodies = true
				ray_query.collision_mask = collision_mask


func _to_local_direction(dir:Vector2)->Vector2:
	return dir * (Vector2.ONE / projectile.axis_multiplier_resource.value)


func _physics_process(delta:float)->void:
	match movement_type:
		MovementType.PROJECTILE:
			projectile.global_position += (projectile.speed * delta * move_direction) * projectile.axis_multiplier_resource.value
		MovementType.SHAPECAST:
			var _remaining_length:float = projectile.speed * delta
			for i:int in remaining_bounces:
				var _move_vec:Vector2 = _remaining_length * move_direction * projectile.axis_multiplier_resource.value
				shape_cast.target_position = _move_vec
				shape_cast.force_shapecast_update()
				if !shape_cast.is_colliding():
					projectile.global_position += _move_vec
					break
				
				_move_vec *= shape_cast.get_closest_collision_safe_fraction()
				
				remaining_bounces -= 1
				if remaining_bounces == 0:
					projectile.global_position += _move_vec
					bounces_finished.emit()
					set_physics_process(false)
					break
				move_direction = projectile.direction.bounce(shape_cast.get_collision_normal(0))
				projectile.global_position += _move_vec
				projectile.direction = move_direction * projectile.axis_multiplier_resource.value
				bounce_position.emit()
		MovementType.RAYCAST:
			var _remaining_length:float = projectile.speed * delta
			for i:int in remaining_bounces:
				ray_query.from = projectile.global_position
				var _move_vec:Vector2 = _remaining_length * move_direction * projectile.axis_multiplier_resource.value
				ray_query.to = projectile.global_position + _move_vec
				var _collision:Dictionary = world_2d.direct_space_state.intersect_ray(ray_query)
				if _collision.is_empty():
					## completed movement
					projectile.global_position = ray_query.to
					break
				
				var _moved_distance:Vector2 = ray_query.to - ray_query.from
				var _max_move:float = max(_move_vec.x, _move_vec.y)
				if _max_move != 0.0:
					_remaining_length -= _remaining_length * max(_moved_distance.x, _moved_distance.y)/ _max_move
				
				projectile.global_position = _collision.position
				remaining_bounces -= 1
				if remaining_bounces == 0:
					bounces_finished.emit()
					set_physics_process(false)
					break
				
				move_direction = projectile.direction.bounce(_collision.normal)
				projectile.direction = move_direction * projectile.axis_multiplier_resource.value
				bounce_position.emit()
