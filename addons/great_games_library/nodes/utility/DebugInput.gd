class_name DebugInput
extends Node

@export var node:Node

@export var function_name:StringName

@export var input_event:InputEvent

@export var debug_action_name:StringName = "DebugInput"

func _enter_tree() -> void:
	set_process_input(false)
	if input_event == null:
		return
	if !InputMap.has_action(debug_action_name):
		InputMap.add_action(debug_action_name)
	
	InputMap.action_add_event(debug_action_name, input_event)
	set_process_input(true)

func _exit_tree() -> void:
	if !InputMap.has_action(debug_action_name):
		return
	InputMap.erase_action(debug_action_name)


func _input(event:InputEvent)->void:
	if !event.is_action_pressed(debug_action_name):
		return
	node.call(function_name)
