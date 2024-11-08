class_name AreaTransmitter2D
extends Area2D

@export var enabled:bool = true

func set_enabled(value:bool)->void:
	enabled = value

func _ready()->void:
	process_mode = PROCESS_MODE_ALWAYS
	
	# BUG: https://github.com/godotengine/godot/issues/17238
	#set_monitorable.call_deferred(false)
