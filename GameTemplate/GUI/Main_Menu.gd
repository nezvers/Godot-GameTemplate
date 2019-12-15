extends CanvasLayer

func _on_NewGame_pressed()->void:
	Event.emit_signal("NewGame")

func _on_Options_pressed()->void:
	Event.emit_signal("Options")

func _on_Exit_pressed()->void:
	Event.emit_signal("Exit")
