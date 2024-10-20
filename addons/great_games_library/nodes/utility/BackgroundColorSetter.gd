class_name BackgroundColorSetter
extends Node

## Games background color will be set to this color when _ready
@export var color:Color

func _ready() -> void:
	RenderingServer.set_default_clear_color(color)
