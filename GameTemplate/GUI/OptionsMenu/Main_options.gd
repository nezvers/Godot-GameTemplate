extends CanvasLayer

var show:bool = false setget set_show

func _ready()->void:
	set_show(false)
	#show main section and hide controls
	find_node("Main").visible = true
	find_node("OptionsControls").visible = false

func set_show(value:bool)->void:
	show=value
	$Main_Options.visible = value
	Event.Options = value




