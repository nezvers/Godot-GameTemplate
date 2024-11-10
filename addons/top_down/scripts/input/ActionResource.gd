class_name ActionResource
extends SaveableResource

signal updated

@export var pause_action:StringName
@export var pause_inputs:Array[InputEvent]
@export_category("Movement")
@export var left_action:StringName
@export var left_inputs:Array[InputEvent]
@export var right_action:StringName
@export var right_inputs:Array[InputEvent]
@export var up_action:StringName
@export var up_inputs:Array[InputEvent]
@export var down_action:StringName
@export var down_inputs:Array[InputEvent]
@export_category("Aiming")
@export var aim_left_action:StringName
@export var aim_left_inputs:Array[InputEvent]
@export var aim_right_action:StringName
@export var aim_right_inputs:Array[InputEvent]
@export var aim_up_action:StringName
@export var aim_up_inputs:Array[InputEvent]
@export var aim_down_action:StringName
@export var aim_down_inputs:Array[InputEvent]
@export_category("Actions")
@export var action_1_action:StringName
@export var action_1_inputs:Array[InputEvent]
@export var action_2_action:StringName
@export var action_2_inputs:Array[InputEvent]
@export var next_action:StringName
@export var next_inputs:Array[InputEvent]
@export var previous_action:StringName
@export var previous_inputs:Array[InputEvent]

## Variable to not set it again
var is_initialized:bool
## Used to know if use mouse direction or aim inputs
var mouse_aim:bool
## locally keep information about used InputEvents, to be able remove a specific one.
## Could be used to serialize into a JSON
var action_dictionary:Dictionary

func initialize()->void:
	if is_initialized:
		return
	is_initialized = true
	_add_action(pause_action, pause_inputs)
	
	_add_action(left_action, left_inputs)
	_add_action(right_action, right_inputs)
	_add_action(up_action, up_inputs)
	_add_action(down_action, down_inputs)
	
	_add_action(aim_left_action, aim_left_inputs)
	_add_action(aim_right_action, aim_right_inputs)
	_add_action(aim_up_action, aim_up_inputs)
	_add_action(aim_down_action, aim_down_inputs)
	_add_action(action_1_action, action_1_inputs)
	_add_action(action_2_action, action_2_inputs)
	_add_action(next_action, next_inputs)
	_add_action(previous_action, previous_inputs)
	
	updated.emit()


func _add_action(action_name:StringName, input_list:Array[InputEvent])->void:
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		action_dictionary[action_name] = input_list
	
	for _input_event:InputEvent in input_list:
		_action_add_input(action_name, _input_event)

func _action_add_input(action_name:StringName, input_event:InputEvent)->void:
	if InputMap.action_has_event(action_name, input_event):
		return
	InputMap.action_add_event(action_name, input_event)
	
	if !action_dictionary[action_name].has(input_event):
		action_dictionary[action_name].append(input_event)

## Erase a specific InputEvent from an Action
func erase_input(action_name, input_event:InputEvent)->void:
	assert(action_dictionary.has(action_name))
	assert(action_dictionary[action_name].has(input_event))
	
	InputMap.action_erase_event(action_name, input_event)
	action_dictionary[action_name].erase(input_event)
	updated.emit()

## Overwrite input event list
func overwrite_action_inputs(action_name:StringName, input_list:Array[InputEvent])->void:
	if !InputMap.has_action(action_name):
		_add_action(action_name, input_list)
		return
	
	InputMap.action_erase_events(action_name)
	action_dictionary[action_name].clear()
	
	_add_action(action_name, input_list)
	updated.emit()

## Override function for resetting to default values
func reset_resource()->void:
	initialize()

## Override to ad logic for reading loaded data and applying to current instance of the Resource
func prepare_load(data:Resource)->void:
	overwrite_action_inputs(pause_action, data.pause_inputs)
	
	overwrite_action_inputs(left_action, data.left_inputs)
	overwrite_action_inputs(right_action, data.right_inputs)
	overwrite_action_inputs(up_action, data.up_inputs)
	overwrite_action_inputs(down_action, data.down_inputs)
	
	overwrite_action_inputs(aim_left_action, data.aim_left_inputs)
	overwrite_action_inputs(aim_right_action, data.aim_right_inputs)
	overwrite_action_inputs(aim_up_action, data.aim_up_inputs)
	overwrite_action_inputs(aim_down_action, data.aim_down_inputs)
	overwrite_action_inputs(action_1_action, data.action_1_inputs)
	overwrite_action_inputs(action_2_action, data.action_2_inputs)
	overwrite_action_inputs(next_action, data.next_inputs)
	overwrite_action_inputs(previous_action, data.previous_inputs)
