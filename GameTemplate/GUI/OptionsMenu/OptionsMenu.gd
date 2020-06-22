extends CanvasLayer

func _ready()->void:
	#show main section and hide controls
	MenuEvent.connect("Options", self, "on_show_options")
	MenuEvent.Controls = false

func on_show_options(value:bool)->void:
	$Control.visible = value
	MenuEvent.Controls = false


