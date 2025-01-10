class_name BotInput
extends Node2D

signal input_update

@export var enabled:bool = true
@export var axis_multiplier_resource:Vector2Resource
@export var attack_distance:float = 16.0
@export var resource_node:ResourceNode

var axis_compensation:Vector2 # top down movement can use different speed for X&Y axis
var input_resource:InputResource


## Not using automatic setter functions because they are called before _ready during initialization
func _ready()->void:
	# Set to run before mover
	process_physics_priority -= 1
	axis_compensation = Vector2.ONE/axis_multiplier_resource.value
	input_resource = resource_node.get_resource("input")
	assert(input_resource != null)
	set_enabled(enabled)
	
	# in case used with PoolNode
	request_ready()

## Toggle processing for animation state machine
func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)
	if !enabled:
		input_resource.axis = Vector2.ZERO

## Inputs need to be manipulated here
## Modules use this to time their functions
func _physics_process(_delta:float)->void:
	input_update.emit()
