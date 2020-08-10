extends Panel

signal Language_choosen

onready var button:PackedScene = preload("res://Addons/GameTemplate/GUI/Buttons/DefaultButton.tscn")
onready var button_parent:HBoxContainer = $"VBoxContainer/MarginContainer/HBoxContainer"

func _ready()->void:
	MenuEvent.connect("Languages", self, "on_show_languages")
	for language in SettingsLanguage.Language_list:
		var newButton:Button = button.instance()
		button_parent.add_child(newButton)
		newButton.text = "\"" + language + "\""
		newButton.connect("pressed", self, "_on_button_pressed", [language])

func on_show_languages(value:bool)->void:
	visible = value

func _on_button_pressed(value:String)->void:
	SettingsLanguage.Language = SettingsLanguage.Language_dictionary[value] #Settings will emit ReTranslate
	MenuEvent.Languages = false
