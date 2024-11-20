class_name ActionResource
extends SaveableResource

signal updated

@export var pause_action:StringName
@export_category("Actions")
@export var left_action:StringName
@export var right_action:StringName
@export var up_action:StringName
@export var down_action:StringName
@export var aim_left_action:StringName
@export var aim_right_action:StringName
@export var aim_up_action:StringName
@export var aim_down_action:StringName
@export var action_1_action:StringName
@export var action_2_action:StringName
@export var next_action:StringName
@export var previous_action:StringName

@export_category("Keyboard")
@export var pause_kb:InputEvent
@export var left_kb:InputEvent
@export var right_kb:InputEvent
@export var up_kb:InputEvent
@export var down_kb:InputEvent
@export var aim_left_kb:InputEvent
@export var aim_right_kb:InputEvent
@export var aim_up_kb:InputEvent
@export var aim_down_kb:InputEvent
@export var action_1_kb:InputEvent
@export var action_2_kb:InputEvent
@export var next_kb:InputEvent
@export var previous_kb:InputEvent

@export_category("Gamepad")
@export var pause_gp:InputEvent
@export var left_gp:InputEvent
@export var right_gp:InputEvent
@export var up_gp:InputEvent
@export var down_gp:InputEvent
@export var aim_left_gp:InputEvent
@export var aim_right_gp:InputEvent
@export var aim_up_gp:InputEvent
@export var aim_down_gp:InputEvent
@export var action_1_gp:InputEvent
@export var action_2_gp:InputEvent
@export var next_gp:InputEvent
@export var previous_gp:InputEvent

## Variable to not set it again
var is_initialized:bool

## Used to know if use mouse direction or aim inputs
var mouse_aim:bool

## Used to reset to defaults with default_reset()
var default_settings:ActionResource

## Utility function to filter empty events in an array
func _filter_empty(event:InputEvent)->bool:
	return event != null

func _initialize()->void:
	if is_initialized:
		return
	is_initialized = true
	default_settings = self.duplicate()
	
	_init_action(pause_action, [pause_kb, pause_gp].filter(_filter_empty))
	
	_init_action(right_action, [right_kb, right_gp].filter(_filter_empty), 0.2)
	_init_action(left_action, [left_kb, left_gp].filter(_filter_empty), 0.2)
	_init_action(up_action, [up_kb, up_gp].filter(_filter_empty), 0.2)
	_init_action(down_action, [down_kb, down_gp].filter(_filter_empty), 0.2)
	
	_init_action(aim_right_action, [aim_right_kb, aim_right_gp].filter(_filter_empty), 0.1)
	_init_action(aim_left_action, [aim_left_kb, aim_left_gp].filter(_filter_empty), 0.1)
	_init_action(aim_up_action, [aim_up_kb, aim_up_gp].filter(_filter_empty), 0.1)
	_init_action(aim_down_action, [aim_down_kb, aim_down_gp].filter(_filter_empty), 0.1)
	
	_init_action(action_1_action, [action_1_kb, action_1_gp].filter(_filter_empty))
	_init_action(action_2_action, [action_2_kb, action_2_gp].filter(_filter_empty))
	_init_action(next_action, [next_kb, next_gp].filter(_filter_empty))
	_init_action(previous_action, [previous_kb, previous_gp].filter(_filter_empty))
	
	updated.emit()

func _init_action(action_name:StringName, event_list:Array, deadzone:float = 0.5)->void:
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		InputMap.action_set_deadzone(action_name, deadzone)
	
	for event:InputEvent in event_list:
		if InputMap.action_has_event(action_name, event):
			continue
		InputMap.action_add_event(action_name, event)

func _add_action(action_name:StringName)->void:
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)

func _action_add_input(action_name:StringName, input_event:InputEvent)->void:
	if InputMap.action_has_event(action_name, input_event):
		return
	InputMap.action_add_event(action_name, input_event)

## Set a new InputEvent to an Action
func set_input(action_name:StringName, event:InputEvent)->void:
	assert(event != null)
	# When assigning new one previous should have been removed even if it's the same
	assert(InputMap.has_action(action_name))
	if InputMap.action_has_event(action_name, event):
		return
	InputMap.action_add_event(action_name, event)
	updated.emit()

## Erase a specific InputEvent from an Action
func erase_input(action_name:StringName, event:InputEvent)->void:
	assert(InputMap.has_action(action_name))
	if !InputMap.action_has_event(action_name, event):
		return
	InputMap.action_erase_event(action_name, event)
	updated.emit()

## Overwrite input event list.
## TODO: Check how overwriting behaves if arrays are empty
func _overwrite_action_inputs(action_name:StringName, event_list:Array)->void:
	InputMap.action_erase_events(action_name)
	
	for event:InputEvent in event_list:
		if InputMap.action_has_event(action_name, event):
			continue
		InputMap.action_add_event(action_name, event)

## Override function for resetting to default values
func reset_resource()->void:
	_initialize()
	prepare_load(default_settings)
	updated.emit()

## Override to ad logic for reading loaded data and applying to current instance of the Resource
func prepare_load(data:Resource)->void:
	_initialize()
	# TODO: overwrite variables too
	pause_kb = data.pause_kb
	pause_gp = data.pause_gp
	_overwrite_action_inputs(pause_action, [data.pause_kb, data.pause_gp].filter(_filter_empty))
	
	right_kb = data.right_kb
	right_gp = data.right_gp
	left_kb = data.left_kb
	left_gp = data.left_gp
	up_kb = data.up_kb
	up_gp = data.up_gp
	down_kb = data.down_kb
	down_gp = data.down_gp
	_overwrite_action_inputs(right_action, [data.right_kb, data.right_gp].filter(_filter_empty))
	_overwrite_action_inputs(left_action, [data.left_kb, data.left_gp].filter(_filter_empty))
	_overwrite_action_inputs(up_action, [data.up_kb, data.up_gp].filter(_filter_empty))
	_overwrite_action_inputs(down_action, [data.down_kb, data.down_gp].filter(_filter_empty))
	
	aim_right_kb = data.aim_right_kb
	aim_right_gp = data.aim_right_gp
	aim_left_kb = data.aim_left_kb
	aim_left_gp = data.aim_left_gp
	aim_up_kb = data.aim_up_kb
	aim_up_gp = data.aim_up_gp
	aim_down_kb = data.aim_down_kb
	aim_down_gp = data.aim_down_gp
	_overwrite_action_inputs(aim_right_action, [data.aim_right_kb, data.aim_right_gp].filter(_filter_empty))
	_overwrite_action_inputs(aim_left_action, [data.aim_left_kb, data.aim_left_gp].filter(_filter_empty))
	_overwrite_action_inputs(aim_up_action, [data.aim_up_kb, data.aim_up_gp].filter(_filter_empty))
	_overwrite_action_inputs(aim_down_action, [data.aim_down_kb, data.aim_down_gp].filter(_filter_empty))
	
	action_1_kb = data.action_1_kb
	action_1_gp = data.action_1_gp
	action_2_kb = data.action_2_kb
	action_2_gp = data.action_2_gp
	next_kb = data.next_kb
	next_gp = data.next_gp
	previous_kb = data.previous_kb
	previous_gp = data.previous_gp
	_overwrite_action_inputs(action_1_action, [data.action_1_kb, data.action_1_gp].filter(_filter_empty))
	_overwrite_action_inputs(action_2_action, [data.action_2_kb, data.action_2_gp].filter(_filter_empty))
	_overwrite_action_inputs(next_action, [data.next_kb, data.next_gp].filter(_filter_empty))
	_overwrite_action_inputs(previous_action, [data.previous_kb, data.previous_gp].filter(_filter_empty))
	
	updated.emit()
