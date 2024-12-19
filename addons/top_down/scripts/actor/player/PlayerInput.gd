class_name PlayerInput
extends Node

@export var enabled:bool = true

## Used for getting mouse local position
@export var position_node:Node2D

## Offset aim to the body to shoot at shadow collider (feet position)
@export var aim_offset:Vector2
@export var resource_node:ResourceNode
@export var action_resource:ActionResource

var input_resource:InputResource

func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)

func _ready()->void:
	input_resource = resource_node.get_resource("input")
	assert(input_resource != null)
	
	# Read input before mover
	process_physics_priority -= 1
	set_enabled(enabled)

func _input(event:InputEvent)->void:
	if event is InputEventMouseMotion:
		action_resource.mouse_aim = true
		var aim_direction:Vector2 = position_node.get_local_mouse_position() + aim_offset
		input_resource.set_aim_direction(aim_direction.normalized())
		return
	# mark that mouse is not used
	if event.is_action(action_resource.aim_left_action):
		action_resource.mouse_aim = false
		return
	if event.is_action(action_resource.aim_right_action):
		action_resource.mouse_aim = false
		return
	if event.is_action(action_resource.aim_up_action):
		if event is InputEventJoypadMotion && abs(event.axis_value) < action_resource.aim_deadzone:
			return
		action_resource.mouse_aim = false
		return
	if event.is_action(action_resource.aim_down_action):
		if event is InputEventJoypadMotion && abs(event.axis_value) < action_resource.aim_deadzone:
			return
		action_resource.mouse_aim = false
		return

func _physics_process(_delta:float)->void:
	# Walking direction
	var _axis:Vector2 = Vector2(Input.get_axis(action_resource.left_action, action_resource.right_action), Input.get_axis(action_resource.up_action, action_resource.down_action))
	# Analog sticks sucks for diagonals
	#_axis = Vector2(ceil(abs(_axis.x)) * sign(_axis.x), ceil(abs(_axis.y)) * sign(_axis.y) )
	
	var _length:float = _axis.length()
	if _length > 0.01:
		_axis = _axis.normalized()
	
	input_resource.set_axis(_axis)
	
	# Aiming
	if !action_resource.mouse_aim:
		var _aim:Vector2 = Vector2(Input.get_axis(action_resource.aim_left_action, action_resource.aim_right_action), Input.get_axis(action_resource.aim_up_action, action_resource.aim_down_action))
		if _aim.length() > 0.01:
			#_aim = Vector2(ceil(abs(_aim.x)) * sign(_aim.x), ceil(abs(_aim.y)) * sign(_aim.y) )
			input_resource.set_aim_direction(_aim.normalized())
	
	# Shooting
	input_resource.set_action(Input.is_action_pressed(action_resource.action_1_action))
	
	var weapon_switch_dir:int = int(Input.is_action_just_released(action_resource.previous_action)) - int(Input.is_action_just_released(action_resource.next_action))
	if weapon_switch_dir != 0:
		input_resource.set_switch_weapon(weapon_switch_dir)
	
	# Dashing
	input_resource.set_action_2(Input.is_action_pressed(action_resource.action_2_action))
