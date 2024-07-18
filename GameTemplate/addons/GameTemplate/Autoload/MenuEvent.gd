extends Node

signal OptionsSignal
signal ControlsSignal
signal LanguagesSignal
signal PausedSignal
signal RefocusSignal

#For section tracking
var Options_val = false: set = set_options
var Controls_val = false: set = set_controls
var Languages_val = false: set = set_languages
var Paused_val = false: set = set_paused

func set_options(value:bool)->void:
	Options_val = value
	emit_signal("OptionsSignal", Options_val)

func set_controls(value:bool)->void:
	Controls_val = value
	emit_signal("ControlsSignal", Controls_val)

func set_languages(value:bool)->void:
	Languages_val = value
	emit_signal("LanguagesSignal", Languages_val)

func set_paused(value:bool)->void:
	Paused_val = value
	get_tree().paused = Paused_val
	emit_signal("PausedSignal", Paused_val)

func _ready()->void:
	process_mode = Node.PROCESS_MODE_ALWAYS										#when pause menu allows reading inputs

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Languages_val:
			set_languages(false)
		elif Controls_val:
			# ignore back button when entering key
			if !get_tree().get_nodes_in_group("KeyBinding")[0].visible:
				set_controls(false)
			else:
				return
		elif Options_val:
			set_options(false)
			if PauseMenu.can_show:
				PauseMenu.show_menu(true)
		elif Paused_val:
			PauseMenu.show_menu(false)
		elif PauseMenu.can_show:
			PauseMenu.show_menu(true)
	elif event.is_action_pressed("ui_select"):
		if Paused_val:
			PauseMenu.show_menu(false)
		elif PauseMenu.can_show:
			PauseMenu.show_menu(true)
