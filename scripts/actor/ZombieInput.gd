class_name ZombieInput
extends Node2D

signal state_changed

@export var enabled:bool = true
## Commands the movement
@export var mover:MoverTopDown2D
## Used to detect player
@export var player_detector:Area2D
## How close to walk to start an attack
@export var minimal_distance:Vector2 = Vector2(20.0, 20.0)
## Weapon will execute an attack and spawning projectiles
@export var weapon:Weapon

var axis_compensation:Vector2 # top down movement can use different speed for X&Y axis
enum StateType {NONE, IDLE, CHASE, ATTACK}
var state: = StateType.IDLE

## A place to react on state change
func set_state(value:StateType)->void:
	if value == state:
		return
	state = value
	state_changed.emit()

## Not using automatic setter functions because they are called before _ready during initialization
func _ready()->void:
	# Set to run before mover
	process_physics_priority -= 1
	axis_compensation = Vector2.ONE/mover.axis_multiplier
	set_enabled(enabled)
	player_detector.monitorable = false
	player_detector.collision_layer = 0
	player_detector.collision_mask = 2

## Toggle processing for animation state machine
func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)
	if !enabled:
		mover.input_resource.axis = Vector2.ZERO
		set_state(StateType.NONE)
	#print("ZombieInput [INFO]: set_enabled = ", enabled)

func _physics_process(_delta:float)->void:
	var body_list:Array[Node2D] = player_detector.get_overlapping_bodies()
	if body_list.is_empty():
		mover.input_resource.axis = Vector2.ZERO
		set_state(StateType.IDLE)
		return
	
	# TODO: decision logic for multiple possible targets
	var target:Node2D = body_list.front()
	var direction:Vector2 = target.global_position - global_position
	
	if abs(direction.x) < minimal_distance.x && abs(direction.y) < minimal_distance.y:
		# close enough
		mover.input_resource.axis = Vector2.ZERO
		set_state(StateType.ATTACK)
		if weapon.enabled:
			mover.input_resource.aim_direction = direction.normalized()
		mover.input_resource.set_action(weapon.enabled)
		return
	
	# compensate if using different axis speed multipliers
	direction *= axis_compensation
	mover.input_resource.axis = direction.normalized()
	set_state(StateType.CHASE)
