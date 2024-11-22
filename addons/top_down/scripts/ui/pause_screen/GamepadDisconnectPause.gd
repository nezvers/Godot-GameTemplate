class_name GamepadDisconnectPause
extends Node

@export var pause_resource:BoolResource

func _ready()->void:
	Input.joy_connection_changed.connect(on_joy_connection_changed)

func on_joy_connection_changed(_device: int, connected: bool)->void:
	if connected:
		return
	if pause_resource.value == true:
		return
	pause_resource.set_value(true)
