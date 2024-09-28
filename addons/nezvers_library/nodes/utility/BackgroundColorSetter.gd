class_name BackgroundColorSetter
extends Node

@export var color:Color

func _ready() -> void:
	RenderingServer.set_default_clear_color(color)
