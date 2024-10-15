class_name PlayerInput
extends Node

@export var enabled:bool = true
@export var mover:MoverTopDown2D
## Offset aim to the body to shoot at shadow collider (feet position)
@export var aim_offset:Vector2


func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)

func _ready()->void:
	# Read input before mover
	process_physics_priority -= 1
	set_enabled(enabled)

func _physics_process(_delta:float)->void:
	# Walking direction
	var axis:Vector2 = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if axis.length() > 1.0:
		axis = axis.normalized()
	mover.input_resource.set_axis(axis)
	
	# Aiming
	var aim_direction:Vector2 = mover.get_local_mouse_position() + aim_offset
	mover.input_resource.set_aim_direction(aim_direction.normalized())
	
	# Shooting
	mover.input_resource.set_action(Input.is_action_pressed("shoot"))
	
	var weapon_switch_dir:int = int(Input.is_action_just_released("weapon_up")) - int(Input.is_action_just_released("weapon_down"))
	if weapon_switch_dir != 0:
		mover.input_resource.set_switch_weapon(weapon_switch_dir)
	
	# Dashing
	mover.input_resource.set_action_2(Input.is_action_pressed("dash"))
