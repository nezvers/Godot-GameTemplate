class_name Projectile2D
extends Node2D

signal prepare_exit_event

## Travelling speed
@export var speed:float

## Direction to travel
@export var direction: = Vector2.RIGHT

## Used to fake angled perspective
@export var axis_multiplier_resource:Vector2Resource

## Each projectile contribute to the total damage value with multiply
@export var damage_multiply:float = 1.0

## Force pushing a damage receiver
@export var kickback_strength:float = 120.0

## Holds information about damage stats and events
@export var damage_resource:DamageResource
@export_flags_2d_physics var collision_mask:int

## When `prepare_exit()` is called automatically call `queue_free()`
@export var auto_free:bool = true
@export var pool_node:PoolNode

var move_direction:Vector2

func _ready()->void:
	move_direction = to_local_direction(direction).normalized()

func to_local_direction(dir:Vector2)->Vector2:
	return dir * (Vector2.ONE / axis_multiplier_resource.value)

func _physics_process(delta:float)->void:
	global_position += speed * delta * move_direction * axis_multiplier_resource.value


func prepare_exit()->void:
	set_physics_process(false)
	prepare_exit_event.emit()
	if auto_free:
		remove()

## created to call from Tween, Timer, AnimationPlayer or anything else
func remove()->void:
	pool_node.pool_return()
