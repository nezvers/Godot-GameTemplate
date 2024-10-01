class_name DashAbility
extends Node

@export var enabled:bool = true
@export var mover:MoverTopDown2D
@export var impulse_strength:float = 88.0
@export var cooldown_time:float = 0.8

var is_cooldown:bool = false

func _ready()->void:
	set_enabled(enabled)

func set_enabled(value:bool)->void:
	enabled = value
	if enabled:
		if !mover.input_resource.action_2_pressed.is_connected(dash_pressed):
			mover.input_resource.action_2_pressed.connect(dash_pressed)
	else:
		if mover.input_resource.action_2_pressed.is_connected(dash_pressed):
			mover.input_resource.action_2_pressed.disconnect(dash_pressed)

func dash_pressed()->void:
	if is_cooldown:
		return
	mover.add_impulse(mover.input_resource.axis * impulse_strength)
	is_cooldown = true
	var tween:Tween = create_tween()
	tween.tween_callback(cooldown_over).set_delay(cooldown_time)

func cooldown_over()->void:
	is_cooldown = false
	if mover.input_resource.action_2:
		dash_pressed()
