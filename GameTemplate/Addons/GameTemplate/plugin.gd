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
	'HtmlFocus'				: 'res://Addons/GameTemplate/Autoload/HtmlFocus.scn',
	'Game'					: 'res://Addons/GameTemplate/Autoload/Game.gd',
	'ScreenFade'			: 'res://Addons/GameTemplate/Autoload/ScreenFade.scn',
	'Hud'					: 'res://Addons/GameTemplate/Autoload/Hud.scn',
	'PauseMenu'				: 'res://Addons/GameTemplate/Autoload/PauseMenu.scn',
	'MenuEvent'				: 'res://Addons/GameTemplate/Autoload/MenuEvent.gd',
	'Music'					: 'res://Addons/GameTemplate/Autoload/Music.scn',
	'SfxManager'			: 'res://Addons/GameTemplate/Autoload/SfxManager.gd',
	'Options'				: 'res://Addons/GameTemplate/Autoload/Options.scn',
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

