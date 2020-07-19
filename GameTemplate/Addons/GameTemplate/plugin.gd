tool
extends EditorPlugin

const autoload_order: = [
	'Settings',
	'Game',
	'Hud',
	'GuiBrain',
	'MenuEvent',
	'SceneLoader',
	'Music'
]
const autoload_list: = {
	'Game'			: 'res://Addons/GameTemplate/Autoload/Game/Game.tscn',
	'Hud'			: 'res://Addons/GameTemplate/Autoload/Game/HUD.tscn',
	'GuiBrain'		: 'res://Addons/GameTemplate/Autoload/GuiBrain.gd',
	'MenuEvent'		: 'res://Addons/GameTemplate/Autoload/MenuEvent.gd',
	'SceneLoader'	: 'res://Addons/GameTemplate/Autoload/SceneLoader.gd',
	'Settings'		: 'res://Addons/GameTemplate/Autoload/Settings.gd',
	'Music'			: 'res://Addons/GameTemplate/Autoload/Game/Music.tscn'}


func _enter_tree():
	for key in autoload_order:
		add_autoload_singleton(key, autoload_list[key])


func _exit_tree():
	var keys: = autoload_list.keys()
	for key in keys:
		remove_autoload_singleton(key)


func has_main_screen():
	return false


func get_plugin_name():
	return "GameTemplate"

