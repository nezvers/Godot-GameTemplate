extends CanvasLayer

export (String, FILE, "*.tscn") var Main_Menu: String

func _ready()->void:
	Event.connect("Paused", self, "on_show_paused")
	Event.connect("Options", self, "on_show_options")
	Event.Paused = false
	#Localization
	Settings.connect("ReTranslate", self, "retranslate")

func on_show_paused(value:bool)->void:
	#Signals allow each module have it's own response logic
	$Control.visible = value
	get_tree().paused = value

func on_show_options(value:bool)->void:
	if !Event.MainMenu:
		$Control.visible = !value

func _input(event)->void: #FIX - I'd like to remove input monitoring so only GUI_brain monitors
	if event.is_action_pressed("ui_cancel"):
		var MainMenu = get_node("../Levels/MainMenu")
		if !Event.MainMenu:
			if !Event.Paused:
				Event.Paused = true
			elif !Event.Options:
				Event.Paused = false

func _on_Resume_pressed():
	Event.Paused = false #setget triggers signal and responding to it hide GUI

func _on_Restart_pressed():
	Event.emit_signal("Restart")
	Event.Paused = false #setget triggers signal and responding to it hide GUI

func _on_Options_pressed():
	Event.Options = true

func _on_MainMenu_pressed():
	Event.emit_signal("ChangeScene", Main_Menu)
	Event.Paused = false

func _on_Exit_pressed():
	Event.emit_signal("Exit")

func retranslate()->void:
	find_node("Resume").text = tr("RESUME")
	find_node("Restart").text = tr("RESTART")
	find_node("Options").text = tr("OPTIONS")
	find_node("MainMenu").text = tr("MAIN_MENU")
	find_node("Exit").text = tr("EXIT")









