extends CanvasLayer

@export var First_Level: String # (String, FILE, "*.tscn")
@onready var exit: Button = $BG/MarginContainer/VBoxMain/HBoxContainer/ButtonContainer/Exit

func _ready()->void:
	get_tree().get_nodes_in_group("MainMenu")[0].grab_focus()
	MenuEvent.connect("OptionsSignal", on_options)
	if OS.get_name() == "HTML5":
		exit.visible = false
	#Localization
	SettingsLanguage.connect("ReTranslate", retranslate)
	retranslate()
	

func on_options(value:bool)->void:
	if !value && !MenuEvent.Paused_val:
		get_tree().get_nodes_in_group("MainMenu")[0].grab_focus()

func _on_NewGame_pressed()->void:
	Game.emit_signal("NewGame")
	Game.emit_signal("ChangeScene", First_Level)

func _on_Options_pressed()->void:
	MenuEvent.Options_val = true

func _on_Exit_pressed()->void:
	Game.emit_signal("Exit")

#Localization
func retranslate()->void:
	find_child("NewGame").text = tr("NEW_GAME")
	find_child("Options").text = tr("OPTIONS")
	find_child("Exit").text = tr("EXIT")
