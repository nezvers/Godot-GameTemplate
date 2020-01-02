extends Panel

signal Language_choosen

onready var button:PackedScene = preload("res://GUI/Buttons/DefaultButton.tscn")
onready var button_parent:HBoxContainer = $"VBoxContainer/MarginContainer/HBoxContainer"

func _ready()->void:
	for Lang in Settings.Language_list:
		var newButton:Button = button.instance()
		button_parent.add_child(newButton)
		newButton.text = "\"" + Lang.to_upper() + "\""
		newButton.connect("pressed", self, "_on_button_pressed", [Lang])

func _on_button_pressed(value:String)->void:
	Settings.Language = value #Settings will emit ReTranslate