class_name Projectile2D
extends Area2D

signal hit
signal limit_reached

## Travelling speed
@export var speed:float
## Direction to travel
@export var direction: = Vector2.RIGHT
## Used to fake angled perspective
@export var axis_multiplier:Vector2 = Vector2.ONE
## Remove after this time if above 0.0
@export var lifetime:float = 0.0
## Damage dealt to a target
@export var damage:int = 1
## Kickback strength
@export var kickback:float = 120.0
## Projectile is removed when reaching 0
## Starting with negative has infinite count
@export var hit_limit:int = 1
## Does it need queue_free self after hitting limit?
@export var self_remove:bool = false
@export_flags_2d_physics var destroy_collision_mask:int = 1

var is_limit_reached:bool = false

func _ready()->void:
	direction *= Vector2.ONE / axis_multiplier
	direction = direction.normalized()
	area_entered.connect(hitbox_entered)
	body_entered.connect(on_body_entered)
	collision_mask = Bitwise.append_flags(collision_mask, destroy_collision_mask)
	if lifetime > 0.0:
		var tween:Tween = create_tween() # used as a timer
		tween.tween_callback(remove).set_delay(lifetime)

func _physics_process(delta:float)->void:
	global_position += speed * delta * direction * axis_multiplier

## created to call from Tween, Timer, AnimationPlayer or anything else
func remove()->void:
	queue_free()

func hit_solid()->void:
	hit.emit()
	remove()

## Transfer damage to a detected Area2D
func hitbox_entered(area:Area2D)->void:
	if is_limit_reached:
		return
	if !(area is DamageReceiver):
		return
	(area as DamageReceiver).take_damage(damage, direction * kickback)
	hit_limit -= 1
	if hit_limit == 0:
		is_limit_reached = true
		limit_reached.emit()
	hit.emit()
	if is_limit_reached && self_remove:
		remove()

func on_body_entered(body:Node2D)->void:
	if body is TileMapLayer || body is TileMap:
		hit_solid()
		return
	if body.collision_layer & destroy_collision_mask == destroy_collision_mask:
		hit_solid()
