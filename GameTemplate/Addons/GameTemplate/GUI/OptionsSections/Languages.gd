extends VBoxContainer

signal Language_choosen

onready var button:PackedScene = preload("res://addons/GameTemplate/GUI/Buttons/DefaultButton.tscn")
onready var button_parent:HBoxContainer = $"Panel/VBoxContainer/MarginContainer/HBoxContainer"

func _ready()->void:
	MenuEvent.connect("Languages", self, "on_show_languages")
	MenuEvent.Languages = false #just in case project saved with visible Languages
	
	for language in SettingsLanguage.Language_list:			#For each language generate button
		var newButton:Button = button.instance()
		button_parent.add_child(newButton)
		newButton.text = "\"" + language + "\""
		newButton.connect("pressed", self, "_on_language_pressed", [language])
	
	#Localization
	SettingsLanguage.connect("ReTranslate", self, "retranslate")
	retranslate()

func _on_language_pressed(value:String)->void:
	SettingsLanguage.Language = SettingsLanguage.Language_dictionary[value] #Settings will emit ReTranslate signal
	MenuEvent.Languages = false

func _on_Back_pressed()->void:
	MenuEvent.Languages = false

#EVENT SIGNALS
func on_show_languages(value:bool)->void:
	visible = value
	if visible:
		get_tree().get_nodes_in_group("Languages")[0].grab_focus()

#Localization
func retranslate()->void:
	find_node("Back").text = tr("BACK")
