class_name Projectile2D
extends Node2D

signal limit_reached

## Travelling speed
@export var speed:float
## Direction to travel
@export var direction: = Vector2.RIGHT
## Used to fake angled perspective
@export var axis_multiplier:Vector2 = Vector2.ONE
## Remove after this time if above 0.0
@export var lifetime:float = 0.0
## Each projectile contribute to the total damage value with multiply

@export var damage_multiply:float = 1.0
## Force pushing a damage receiver
@export var kickback_strength:float = 120.0
## Projectile is removed when reaching 0
## Starting with negative has infinite count
@export var hit_limit:int = 1
## Does it need queue_free self after hitting limit?
@export var self_remove:bool = false
## Holds information about damage stats and events
@export var damage_resource:DamageResource
@export_group("Damage Source")
## Damage source will detect and deal damage
@export var damage_source:DamageSource
@export_flags_2d_physics var destroy_collision_mask:int = 1
@export_flags_2d_physics var collision_mask:int

var is_limit_reached:bool = false

func _ready()->void:
	# fill last values that projectile is controlling
	damage_resource.kickback_strength = kickback_strength
	damage_resource.projectile_multiply = damage_multiply
	
	damage_source.collision_mask = Bitwise.append_flags(damage_source.collision_mask, collision_mask)
	damage_source.collision_mask = Bitwise.append_flags(damage_source.collision_mask, destroy_collision_mask)
	damage_source.damage_resource = damage_resource
	damage_source.damage_resource = damage_resource
	damage_source.hit.connect(on_hit)
	damage_source.hit_solid.connect(remove)
	
	
	direction *= Vector2.ONE / axis_multiplier
	direction = direction.normalized()
	if lifetime > 0.0:
		var tween:Tween = create_tween() # used as a timer
		tween.tween_callback(remove).set_delay(lifetime)

func _physics_process(delta:float)->void:
	global_position += speed * delta * direction * axis_multiplier

func on_hit()->void:
	damage_resource.direction = direction
	# TODO: this hit limit solution looks dumb
	if is_limit_reached:
		return
	hit_limit -= 1
	if hit_limit == 0:
		limit_reached.emit()
		if self_remove:
			remove()

## created to call from Tween, Timer, AnimationPlayer or anything else
func remove()->void:
	queue_free()
