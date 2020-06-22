extends CanvasLayer

export (String, FILE, "*.tscn") var First_Level: String

func _ready()->void:
	MenuEvent.MainMenu = true
	guiBrain.gui_collect_focusgroup()
	if Settings.HTML5:
		$"BG/MarginContainer/VBoxMain/HBoxContainer/ButtonContainer/Exit".visible = false
	#Localization
	Settings.connect("ReTranslate", self, "retranslate")
	retranslate()

func _process(delta):
	$BG.visible = !MenuEvent.Options

func _exit_tree()->void:
	MenuEvent.MainMenu = false				#switch bool for easier pause menu detection and more
	guiBrain.gui_collect_focusgroup()	#Force re-collect buttons because main meno wont be there

func _on_NewGame_pressed()->void:
	Event.emit_signal("NewGame")
	Event.emit_signal("ChangeScene", First_Level)

func _on_Options_pressed()->void:
	MenuEvent.Options = true

func _on_Exit_pressed()->void:
	Event.emit_signal("Exit")

#Localization
func retranslate()->void:
	find_node("NewGame").text = tr("NEW_GAME")
	find_node("Options").text = tr("OPTIONS")
	find_node("Exit").text = tr("EXIT")
