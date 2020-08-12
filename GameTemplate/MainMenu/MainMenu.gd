extends CanvasLayer

export (String, FILE, "*.tscn") var First_Level: String

func _ready()->void:
	get_tree().get_nodes_in_group("MainMenu")[0].grab_focus()					#Godot doesn't have buttons auto grab_focus when noone has focus
	MenuEvent.connect("Options", self, "on_options")
	
	if OS.get_name() == "HTML5":
		$"BG/MarginContainer/VBoxMain/HBoxContainer/ButtonContainer/Exit".visible = false
	#Localization
	SettingsLanguage.connect("ReTranslate", self, "retranslate")
	retranslate()

func on_options(value:bool)->void:
	if !value && !MenuEvent.Paused:
		get_tree().get_nodes_in_group("MainMenu")[0].grab_focus()

func _on_NewGame_pressed()->void:
	Game.emit_signal("NewGame")
	Game.emit_signal("ChangeScene", First_Level)

func _on_Options_pressed()->void:
	MenuEvent.Options = true

func _on_Exit_pressed()->void:
	Game.emit_signal("Exit")

#Localization
func retranslate()->void:
	find_node("NewGame").text = tr("NEW_GAME")
	find_node("Options").text = tr("OPTIONS")
	find_node("Exit").text = tr("EXIT")
