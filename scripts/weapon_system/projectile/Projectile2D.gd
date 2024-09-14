class_name Projectile2D
extends Node2D

signal prepare_exit_event

## Travelling speed
@export var speed:float
## Direction to travel
@export var direction: = Vector2.RIGHT
## Used to fake angled perspective
@export var axis_multiplier:Vector2 = Vector2.ONE
## Each projectile contribute to the total damage value with multiply
@export var damage_multiply:float = 1.0
## Force pushing a damage receiver
@export var kickback_strength:float = 120.0
## Holds information about damage stats and events
@export var damage_resource:DamageResource
@export_group("Damage Source")
## Damage source will detect and deal damage
@export var damage_source:DamageSource
@export_flags_2d_physics var destroy_collision_mask:int = 1
@export_flags_2d_physics var collision_mask:int


func _ready()->void:
	# fill last values that projectile is controlling
	damage_resource.kickback_strength = kickback_strength
	damage_resource.projectile_multiply = damage_multiply
	
	# TODO: remove references to damage_source to a separate node
	damage_source.collision_mask = Bitwise.append_flags(damage_source.collision_mask, collision_mask)
	damage_source.collision_mask = Bitwise.append_flags(damage_source.collision_mask, destroy_collision_mask)
	damage_source.damage_resource = damage_resource
	damage_source.hit.connect(on_hit)
	
	direction *= Vector2.ONE / axis_multiplier
	direction = direction.normalized()

func _physics_process(delta:float)->void:
	global_position += speed * delta * direction * axis_multiplier

func on_hit()->void:
	damage_resource.direction = direction


func prepare_exit()->void:
	set_physics_process(false)
	damage_source.monitoring = false
	prepare_exit_event.emit()
	remove()

## created to call from Tween, Timer, AnimationPlayer or anything else
func remove()->void:
	queue_free()
