tool
extends EditorPlugin

const autoload_order: = [
	'SettingsAudio',
	'SettingsControls',
	'SettingsLanguage',
	'SettingsResolution',
	'SettingsSaveLoad',
	'Settings',
	'Options',
	'Game',
	'ScreenFade',
	'PauseMenu',
	'Hud',
	'MenuEvent',
	'Music',
	'SfxManager',
	'HtmlFocus'
]

const autoload_list: = {
	'HtmlFocus'				: 'res://addons/GameTemplate/Autoload/HtmlFocus.tscn',
	'Game'					: 'res://addons/GameTemplate/Autoload/Game.gd',
	'ScreenFade'			: 'res://addons/GameTemplate/Autoload/ScreenFade.tscn',
	'Hud'					: 'res://addons/GameTemplate/Autoload/Hud.tscn',
	'PauseMenu'				: 'res://addons/GameTemplate/Autoload/PauseMenu.tscn',
	'MenuEvent'				: 'res://addons/GameTemplate/Autoload/MenuEvent.gd',
	'Music'					: 'res://addons/GameTemplate/Autoload/Music.tscn',
	'SfxManager'			: 'res://addons/GameTemplate/Autoload/SfxManager.gd',
	'Options'				: 'res://addons/GameTemplate/Autoload/Options.tscn',
	'Settings'				: 'res://addons/GameTemplate/Autoload/Settings.gd',
	'SettingsAudio'			: 'res://addons/GameTemplate/Autoload/SettingsAudio.gd',
	'SettingsControls'		: 'res://addons/GameTemplate/Autoload/SettingsControls.gd',
	'SettingsLanguage'		: 'res://addons/GameTemplate/Autoload/SettingsLanguage.gd',
	'SettingsResolution'	: 'res://addons/GameTemplate/Autoload/SettingsResolution.gd',
	'SettingsSaveLoad'		: 'res://addons/GameTemplate/Autoload/SettingsSaveLoad.gd'}


func _enter_tree():
	for key in autoload_order:
		add_autoload_singleton(key, autoload_list[key])
	print('\n\n\n IMPORTANT: Please set audio bus layout to - "res://addons/GameTemplate/Assets/Audio_bus_layout.tres" \n\n')


func _exit_tree():
	var keys: = autoload_list.keys()
	for key in keys:
		remove_autoload_singleton(key)


func has_main_screen():
	return false


func get_plugin_name():
	return "GameTemplate"
