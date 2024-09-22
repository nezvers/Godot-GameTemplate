class_name MoverTopDown2D
extends Node2D

## Way to disable functionality at _ready
@export var enabled:bool = true
## Node that is doing the physical movement
@export var character:CharacterBody2D
## Stats for movement
@export var actor_stats_resource:ActorStatsResource
## Virtual buttons to react to
@export var input_resource:InputResource
## Used for faking angled perspective movement
@export var axis_multiplier:Vector2 = Vector2(1.0, 1.0)




## Way to disable functionality during the gameplay
func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)

func _ready()->void:
	set_enabled(enabled)

func _physics_process(delta:float)->void:
	var target_velocity:Vector2 = actor_stats_resource.max_speed * input_resource.axis * axis_multiplier
	character.velocity += get_impulse(character.velocity, target_velocity, actor_stats_resource.acceleration, delta)
	var _collided:bool = character.move_and_slide()

## Adds an impulse to velocity, like a kickback
func add_impulse(impulse:Vector2)->void:
	character.velocity += impulse

func get_impulse(velocity:Vector2, target_velocity:Vector2, acceleration:float, delta:float)->Vector2:
	var direction:Vector2 = target_velocity - character.velocity 
	var distance:float = direction.length()
	acceleration = delta * acceleration
	var ratio:float = 0
	if distance > 0.0:
		ratio = min(acceleration / distance, 1.0)
	return (direction * ratio)
