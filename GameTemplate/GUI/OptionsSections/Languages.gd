extends Panel

signal Language_choosen

onready var button:PackedScene = preload("res://GUI/Buttons/DefaultButton.tscn")
onready var button_parent:HBoxContainer = $"VBoxContainer/MarginContainer/HBoxContainer"

func _ready()->void:
	Event.connect("Languages", self, "on_show_languages")
	for Lang in Settings.Language_list:
		var newButton:Button = button.instance()
		button_parent.add_child(newButton)
		newButton.text = "\"" + Lang.to_upper() + "\""
		newButton.connect("pressed", self, "_on_button_pressed", [Lang])

func on_show_languages(value:bool)->void:
	visible = value

func _on_button_pressed(value:String)->void:
	Settings.Language = value #Settings will emit ReTranslate