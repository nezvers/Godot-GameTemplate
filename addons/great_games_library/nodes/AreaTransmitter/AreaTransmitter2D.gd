class_name AreaTransmitter2D
extends Area2D

@export var enabled:bool = true

func set_enabled(value:bool)->void:
	enabled = value

func _ready()->void:
	set_monitorable.call(false)
	process_mode = PROCESS_MODE_ALWAYS
