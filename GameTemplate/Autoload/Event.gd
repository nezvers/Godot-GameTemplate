extends Node

signal ChangeScene
signal MainMenu
signal NewGame
signal Continue
signal Resume
signal Restart
signal Options
signal Controls
signal Languages
signal Paused
signal Exit
signal Refocus

#For section tracking
var MainMenu:bool = false setget set_main_menu
var Options:bool = false setget set_options
var Controls:bool = false setget set_controls
var Languages:bool = false setget set_languages
var Paused: bool = false setget set_paused

func set_main_menu(value:bool)->void:
	MainMenu = value
	emit_signal("MainMenu", MainMenu)

func set_options(value:bool)->void:
	Options = value
	emit_signal("Options", Options)

func set_controls(value:bool)->void:
	Controls = value
	emit_signal("Controls", Controls)

func set_languages(value:bool)->void:
	Languages = value
	emit_signal("Languages", Languages)

func set_paused(value:bool)->void:
	Paused = value
	emit_signal("Paused", Paused)