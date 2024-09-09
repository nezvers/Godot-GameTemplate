class_name RigidCharacterBody2D
extends CharacterBody2D

signal collided

@export var linear_velocity = Vector2.ZERO
@export var gravity: = Vector2(0, 4) : set = set_gravity
@export var dampening: = 0.005 #if too low value it starts gain speed when rolling on the ground
@export_range(0.0, 1.0) var bounciness = 0.5
@export var mass:float = 1.0

var collision:KinematicCollision2D
var remainder:Vector2 = Vector2.ZERO

func set_gravity(value:Vector2)->void:
	gravity = value

## 
func set_linear_velocity(value:Vector2)->void:
	linear_velocity = value

## Add force to velociity
func apply_impulse(value:Vector2)->void:
	linear_velocity += value

func _physics_process(delta)->void:
	rigid_physics(delta)

func rigid_physics(delta)->void:
	linear_velocity += gravity #add gravity
	velocity = linear_velocity * delta + remainder
	collision = move_and_collide(linear_velocity * delta + remainder) #apply physics
	linear_velocity = linear_velocity * (1 - dampening) #reduce speed over time
	if collision: #collision detected
		var normal:Vector2 = collision.get_normal() #surface normal
		var strenght:float = -normal.dot(linear_velocity) #
		var impulse:Vector2 = normal * strenght * (1 - bounciness)
		linear_velocity += impulse #dampen velocity in floor direction
		linear_velocity = linear_velocity.bounce(normal) #bounce off the surface
		remainder = collision.get_remainder().bounce(normal) #add in next frame
		emit_signal("collided", collision, strenght)
		var other: = collision.get_collider()
		if other is RigidCharacterBody2D:
			var mass_ratio:float = mass / other.mass
			other.apply_impulse(-linear_velocity * mass_ratio)
			linear_velocity /= mass_ratio
	else:
		remainder = Vector2.ZERO #No collision means no remainder
