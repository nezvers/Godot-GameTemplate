extends CanvasLayer

export (String, FILE, "*.tscn") var Main_Menu: String

var show:bool = false setget set_show

func _ready()->void:
	set_show(false)

func set_show(value:bool)->void:
	show=value
	$Control.visible = value
	get_tree().paused = value
	Event.Paused = value

func _input(event)->void:
	if event.is_action_pressed("ui_cancel"):
		var MainMenu = get_node("../Levels/MainMenu")
		if MainMenu == null:
			if !Event.Paused:
				set_show(true)
			else:
				if !Event.Options:
					set_show(false)

func _on_Resume_pressed():
	set_show(false)

func _on_Options_pressed():
	Event.emit_signal("Options")

func _on_MainMenu_pressed():
	Event.emit_signal("ChangeScene", Main_Menu)
	set_show(false)

func _on_Exit_pressed():
	Event.emit_signal("Exit")

