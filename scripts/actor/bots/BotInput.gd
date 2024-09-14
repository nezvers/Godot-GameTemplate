class_name BotInput
extends Node2D

signal input_update

@export var enabled:bool = true
## Commands the movement
@export var mover:MoverTopDown2D
@export var attack_distance:float = 16.0

var axis_compensation:Vector2 # top down movement can use different speed for X&Y axis

## Not using automatic setter functions because they are called before _ready during initialization
func _ready()->void:
	# Set to run before mover
	process_physics_priority -= 1
	axis_compensation = Vector2.ONE/mover.axis_multiplier
	set_enabled(enabled)

## Toggle processing for animation state machine
func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)
	if !enabled:
		mover.input_resource.axis = Vector2.ZERO

## Inputs need to be manipulated here
## Modules use this to time their functions
func _physics_process(_delta:float)->void:
	input_update.emit()
