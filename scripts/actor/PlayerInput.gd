class_name PlayerInput
extends Node

@export var enabled:bool = true
@export var hitbox:Hitbox
@export var mover_top_down:MoverTopDown2D
## Offset aim to the body to shoot at shadow collider (feet position)
@export var aim_offset:Vector2

var input_resource:InputResource

func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)

func _ready()->void:
	input_resource = mover_top_down.input_resource
	set_enabled(enabled)

func _physics_process(_delta:float)->void:
	# Walking direction
	var axis:Vector2 = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if axis.length() > 1.0:
		axis = axis.normalized()
	input_resource.set_axis(axis)
	
	# Aiming
	var aim_direction:Vector2 = mover_top_down.get_local_mouse_position() + aim_offset
	if aim_direction.length() > 1.0:
		aim_direction = aim_direction.normalized()
	input_resource.set_aim_direction(aim_direction)
	
	# Shooting
	input_resource.set_action(Input.is_action_pressed("shoot"))
