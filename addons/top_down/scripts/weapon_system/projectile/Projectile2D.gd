class_name Projectile2D
extends Node2D

signal prepare_exit_event

## Travelling speed
@export var speed:float

## Lerp movement use it for arriving at target position
@export var time:float

## Direction to travel.
@export var direction: = Vector2.ZERO

## Lerp movement mode uses for targeted position
@export var destination: = Vector2.ZERO

## Used to fake angled perspective
@export var axis_multiplier_resource:Vector2Resource

## Holds information about damage stats and events
@export var damage_data_resource:DamageDataResource

@export_flags_2d_physics var collision_mask:int

## When `prepare_exit()` is called automatically call `queue_free()`
@export var auto_free:bool = true

@export var pool_node:PoolNode

## TODO: Use to calculate initial travel when spawned late due to game frame
var lifetime:float

func prepare_exit()->void:
	set_physics_process(false)
	prepare_exit_event.emit()
	if auto_free:
		remove()

## created to call from Tween, Timer, AnimationPlayer or anything else
func remove()->void:
	pool_node.pool_return()
