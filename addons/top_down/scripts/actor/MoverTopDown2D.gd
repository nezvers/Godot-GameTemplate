class_name MoverTopDown2D
extends Node

## Way to disable functionality at _ready
@export var enabled:bool = true

## Node that is doing the physical movement
@export var character:CharacterBody2D

## Used for faking angled perspective movement
@export var axis_multiplier_resource:Vector2Resource
@export var resource_node:ResourceNode
@export var debug:bool


## Virtual buttons to react to
var input_resource:InputResource

## Stats for movement
var actor_stats_resource:ActorStatsResource

## Way to disable functionality during the gameplay
func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)

func _ready()->void:
	input_resource = resource_node.get_resource("input")
	assert(input_resource != null)
	
	actor_stats_resource = resource_node.get_resource("movement")
	assert(actor_stats_resource != null)
	
	var _push_resource = resource_node.get_resource("push")
	assert(_push_resource != null)
	_push_resource.impulse_event.connect(add_impulse)
	
	set_physics_process(false)
	## Workaround for spawning overlaping instances
	if character.test_move(character.global_transform, Vector2.ZERO):
		character.global_position.x += 8.0
		character.move_and_collide(Vector2(8.0, 0.0))
		character.velocity = Vector2.ZERO
	
	set_enabled(enabled)
	# in case used with PoolNode
	request_ready()
	character.velocity = Vector2.ZERO
	tree_exiting.connect(_push_resource.impulse_event.disconnect.bind(add_impulse), CONNECT_ONE_SHOT)

func _physics_process(delta:float)->void:
	var target_velocity:Vector2 = actor_stats_resource.max_speed * input_resource.axis * axis_multiplier_resource.value
	
	character.velocity += get_impulse(character.velocity, target_velocity, actor_stats_resource.acceleration, delta)
	character.velocity -= character.get_platform_velocity()
	
	var _collided:bool = character.move_and_slide()

## Adds an impulse to velocity, like a kickback
func add_impulse(impulse:Vector2)->void:
	character.velocity += impulse

## Calculate impulse Vector2 for delta time amount
func get_impulse(velocity:Vector2, target_velocity:Vector2, acceleration:float, delta:float)->Vector2:
	var direction:Vector2 = target_velocity - velocity 
	var distance:float = direction.length()
	acceleration = delta * acceleration
	var ratio:float = 0
	if distance > 0.0:
		ratio = min(acceleration / distance, 1.0)
	return (direction * ratio)
