extends VBoxContainer

signal Language_choosen

@onready var button:PackedScene = preload("res://addons/GameTemplate/GUI/Buttons/DefaultButton.tscn")
@onready var button_parent:GridContainer = $"Panel/VBoxContainer/MarginContainer/HBoxContainer"

func _ready()->void:
	MenuEvent.connect("LanguagesSignal", on_show_languages)
	MenuEvent.Languages_val = false #just in case project saved with visible Languages
	
	for language in SettingsLanguage.Language_list:			#For each language generate button
		var newButton:Button = button.instantiate()
		button_parent.add_child(newButton)
		newButton.text = "\"" + language + "\""
		newButton.connect("pressed", _on_language_pressed.bind(language))
	
	#Localization
	SettingsLanguage.connect("ReTranslate", retranslate)
	retranslate()

func _on_language_pressed(value:String)->void:
	SettingsLanguage.Language = SettingsLanguage.Language_dictionary[value] #Settings will emit ReTranslate signal
	MenuEvent.Languages_val = false

func _on_Back_pressed()->void:
	MenuEvent.Languages_val = false

#EVENT SIGNALS
func on_show_languages(value:bool)->void:
	visible = value
	if visible:
		get_tree().get_nodes_in_group("Languages")[0].grab_focus()

#Localization
func retranslate()->void:
	find_child("Back").text = tr("BACK")
