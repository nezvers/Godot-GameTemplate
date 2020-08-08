tool
extends EditorPlugin

const autoload_order: = [
	'SettingsAudio',
	'SettingsControls',
	'SettingsLanguage',
	'SettingsResolution',
	'SettingsSaveLoad',
	'Settings',
	'Game',
	'ScreenFade',
	'Hud',
	'GuiBrain',
	'MenuEvent',
	#'SceneLoader',
	'Music'
	
]
const autoload_list: = {
	'Game'					: 'res://Addons/GameTemplate/Autoload/Game/Game.tscn',
	'ScreenFade'			: 'res://Addons/GameTemplate/Autoload/ScreenFade.tscn',
	'Hud'					: 'res://Addons/GameTemplate/Autoload/Game/HUD.tscn',
	'GuiBrain'				: 'res://Addons/GameTemplate/Autoload/GuiBrain.gd',
	'MenuEvent'				: 'res://Addons/GameTemplate/Autoload/MenuEvent.gd',
	#'SceneLoader'			: 'res://Addons/GameTemplate/Autoload/SceneLoader.gd',
	'Music'					: 'res://Addons/GameTemplate/Autoload/Game/Music.tscn',
	'Settings'				: 'res://Addons/GameTemplate/Autoload/Settings.gd',
	'SettingsAudio'			: 'res://Addons/GameTemplate/Autoload/SettingsAudio.gd',
	'SettingsControls'		: 'res://Addons/GameTemplate/Autoload/SettingsControls.gd',
	'SettingsLanguage'		: 'res://Addons/GameTemplate/Autoload/SettingsLanguage.gd',
	'SettingsResolution'	: 'res://Addons/GameTemplate/Autoload/SettingsResolution.gd',
	'SettingsSaveLoad'		: 'res://Addons/GameTemplate/Autoload/SettingsSaveLoad.gd'}


func _enter_tree():
	for key in autoload_order:
		add_autoload_singleton(key, autoload_list[key])
	print('\n\n\n IMPORTANT: Please set audio bus layout to - "res://Addons/GameTemplate/Assets/Audio_bus_layout.tres" \n\n')


func _exit_tree():
	var keys: = autoload_list.keys()
	for key in keys:
		remove_autoload_singleton(key)


func has_main_screen():
	return false


func get_plugin_name():
	return "GameTemplate"

