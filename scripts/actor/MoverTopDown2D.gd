class_name MoverTopDown2D
extends Node2D

## Way to disable functionality at _ready
@export var enabled:bool = true
## Node that is doing the physical movement
@export var character_body:CharacterBody2D
## Stats for movement
@export var actor_stats_resource:ActorStatsResource
## Virtual buttons to react to
@export var input_resource:InputResource
## Used for faking angled perspective movement
@export var axis_multiplier:Vector2 = Vector2(1.0, 1.0)

## Projected maximal velocity
var target_velocity:Vector2
## Ammount of velocity acceleration
var acceleration:float


## Way to disable functionality during the gameplay
func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)

func _ready()->void:
	set_enabled(enabled)

func _physics_process(delta:float)->void:
	target_velocity = actor_stats_resource.max_speed * input_resource.axis * axis_multiplier
	acceleration = delta * actor_stats_resource.acceleration
	character_body.velocity = character_body.velocity.move_toward(target_velocity, acceleration)
	
	if character_body.velocity.length_squared() > 0.01:
		# Bug workaround
		character_body.move_and_slide()

## Adds an impulse to velocity, like a kickback
func add_impulse(impulse:Vector2)->void:
	character_body.velocity += impulse
