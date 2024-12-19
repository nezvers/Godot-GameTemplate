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
@export var kickback_multiply:float = 1.0

## Holds information about damage stats and events
@export var damage_resource:DamageResource

@export_flags_2d_physics var collision_mask:int

## When `prepare_exit()` is called automatically call `queue_free()`
@export var auto_free:bool = true

@export var pool_node:PoolNode

## TODO: Used to calculate initial travel when spawned late due to game frame
var lifetime:float

func prepare_exit()->void:
	set_physics_process(false)
	prepare_exit_event.emit()
	if auto_free:
		remove()

## created to call from Tween, Timer, AnimationPlayer or anything else
func remove()->void:
	pool_node.pool_return()
