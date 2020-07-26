extends CanvasLayer

func _ready()->void:
	MenuEvent.connect("Paused", self, "on_show_paused")
	MenuEvent.connect("Options", self, "on_show_options")
	MenuEvent.Paused = false
	#Localization
	SettingsLanguage.connect("ReTranslate", self, "retranslate")

func on_show_paused(value:bool)->void:
	#Signals allow each module have it's own response logic
	$Control.visible = value
	get_tree().paused = value

func on_show_options(value:bool)->void:
	if !MenuEvent.MainMenu:
		$Control.visible = !value

func _on_Resume_pressed()->void:
	MenuEvent.Paused = false #setget triggers signal and responding to it hide GUI

func _on_Restart_pressed()->void:
	Game.emit_signal("Restart")
	MenuEvent.Paused = false #setget triggers signal and responding to it hide GUI

func _on_Options_pressed()->void:
	MenuEvent.Options = true

func _on_MainMenu_pressed()->void:
	Game.emit_signal("ChangeScene", Game.main_menu)
	MenuEvent.Paused = false

func _on_Exit_pressed()->void:
	Game.emit_signal("Exit")

func retranslate()->void:
	find_node("Resume").text = tr("RESUME")
	find_node("Restart").text = tr("RESTART")
	find_node("Options").text = tr("OPTIONS")
	find_node("MainMenu").text = tr("MAIN_MENU")
	find_node("Exit").text = tr("EXIT")









