extends Node

signal Options
signal Controls
signal Languages
signal Paused
signal Refocus

#For section tracking
var Options:bool = false setget set_options
var Controls:bool = false setget set_controls
var Languages:bool = false setget set_languages
var Paused: bool = false setget set_paused

func set_options(value:bool)->void:
	Options = value
	emit_signal("Options", Options)
	if Options:
		get_tree().get_nodes_in_group("OptionsMain")[0].grab_focus()
	elif Paused:
		get_tree().get_nodes_in_group("Pause")[0].grab_focus()

func set_controls(value:bool)->void:
	Controls = value
	emit_signal("Controls", Controls)
	if Controls:
		get_tree().get_nodes_in_group("OptionsControls")[0].grab_focus()
	else:
		get_tree().get_nodes_in_group("OptionsMain")[0].grab_focus()

func set_languages(value:bool)->void:
	Languages = value
	emit_signal("Languages", Languages)
	if !Languages:
		get_tree().get_nodes_in_group("OptionsMain")[0].grab_focus()

func set_paused(value:bool)->void:
	Paused = value
	get_tree().paused = value
	emit_signal("Paused", Paused)
	if Paused:
		get_tree().get_nodes_in_group("Pause")[0].grab_focus()

func _ready()->void:
	pause_mode = Node.PAUSE_MODE_PROCESS

func _unhandled_input(event)->void:
	if event.is_action_pressed("ui_cancel"):									#Triggers pause menu
		if Languages:
			set_languages(false)
		elif Controls:
			set_controls(false)
		elif Options:
			set_options(false)
		elif Paused:
			PauseMenu.show(false)
		elif PauseMenu.can_show:
			PauseMenu.show(true)
