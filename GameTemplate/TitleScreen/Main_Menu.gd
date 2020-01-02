extends CanvasLayer

export (String, FILE, "*.tscn") var First_Level: String

func _ready()->void:
	if Settings.HTML5:
		$"BG/MarginContainer/VBoxMain/HBoxContainer/ButtonContainer/Exit".visible = false
	#Localization
	Settings.connect("ReTranslate", self, "retranslate")
	retranslate()

func _on_NewGame_pressed()->void:
	Event.emit_signal("NewGame")
	Event.emit_signal("ChangeScene", First_Level)

func _on_Options_pressed()->void:
	Event.emit_signal("Options")

func _on_Exit_pressed()->void:
	Event.emit_signal("Exit")

#Localization
func retranslate()->void:
	find_node("NewGame").text = tr("NEW_GAME")
	find_node("Options").text = tr("OPTIONS")
	find_node("Exit").text = tr("EXIT")