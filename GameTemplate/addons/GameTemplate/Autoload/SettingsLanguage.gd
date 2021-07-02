extends Node

signal ReTranslate

#Localization
var translations: = [
	preload("res://addons/GameTemplate/Localization/Localization.en.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.de.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.es.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.fr.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.it.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.lv.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.pt_BR.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.ru.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.sv_SE.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.tr.translation"),
	preload("res://addons/GameTemplate/Localization/Localization.ru.translation")
]
onready var Language:String = TranslationServer.get_locale() setget set_language
var Language_dictionary:Dictionary = {EN = "en", DE = "de", ES = "es", FR = "fr", SE = "sv_SE", BR = "pt_BR", LV = "lv", IT = "it", TR = "tr", RU = "ru"}
var Language_list:Array = Language_dictionary.keys()


#Localization
func add_translations()->void:						#TO-DO need a way to add translations to project through the plugin
	for tran in translations:
		TranslationServer.add_translation(tran)

func set_language(value:String)->void:
	Language = value
	TranslationServer.set_locale(value)
	emit_signal("ReTranslate")

func get_language_data()->String:
	return TranslationServer.get_locale()
