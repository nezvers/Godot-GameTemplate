extends CanvasLayer

func _ready()->void:
	#show main section and hide controls
	Event.connect("Options", self, "on_show_options")
	Event.Controls = false

func on_show_options(value:bool)->void:
	$Control.visible = value
	Event.Controls = false


