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
## Dash timer
@export var time_dash:Timer
## Speed of The Dash
@export var dash_speed:int = 88
## Dash cooldown before new dash
@export var dash_cooldown:float = 0.8

## Projected maximal velocity
var target_velocity:Vector2
## Ammount of velocity acceleration
var acceleration:float
## Dashing status 
var is_dashing:bool = false


## Way to disable functionality during the gameplay
func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)

func _ready()->void:
	set_enabled(enabled)
	if time_dash:
		time_dash.wait_time = 1.0
		time_dash.timeout.connect(reset_dash)

func _physics_process(delta:float)->void:
	target_velocity = actor_stats_resource.max_speed * input_resource.axis * axis_multiplier
	acceleration = delta * actor_stats_resource.acceleration
	character_body.velocity = character_body.velocity.move_toward(target_velocity, acceleration)
	
	var vel2:float = character_body.velocity.length_squared()
	if vel2 > 0.01:
		# Bug workaround
		character_body.move_and_slide()

## Adds an impulse to velocity, like a kickback
func add_impulse(impulse:Vector2)->void:
	character_body.velocity += impulse

## Adds a dash impulse to velocity, like a controlled kickback
func add_dash(direction:Vector2)->void:
	if !time_dash || is_dashing:
		return
	if !is_dashing:
		character_body.velocity += direction * dash_speed
	is_dashing = true
	time_dash.start()

func reset_dash()->void:
	is_dashing = false
