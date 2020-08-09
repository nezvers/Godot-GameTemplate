extends Node


#CONTROLS
var Actions:Array = ["Right", "Left", "Up", "Down", "Jump"]
var ActionControls:Dictionary = {}

#CONTROLS
#func get_controls()->void:
#	if !SettingsSaveLoad.Settings_loaded:
#		default_controls()
#	set_actions_info()

func default_controls()->void:	#Reset to project settings controls
	InputMap.load_from_globals()
	set_actions_info()

func set_actions_info()->void:
	ActionControls.clear()
	for Action in Actions:
		var ActionList:Array = InputMap.get_action_list(Action) #associated controlls to the action
		ActionControls[Action] = ActionList

func print_events_list(ActionList:Array)->void:
	for event in ActionList:
		print(event.as_text())


#SAVING CONTROLS
func get_input_data()->Dictionary:
	var inputs:Dictionary = {}
	for action_name in SettingsControls.Actions:
		var button_list_data:Dictionary = {}
		var button_list:Array = SettingsControls.ActionControls[action_name]
		var index:int = 0
		for button in button_list:
			button_list_data[index] = get_button_data(button)
			index += 1
		inputs[action_name] = button_list_data
	return inputs

func get_button_data(event)->Dictionary:
	var button_data:Dictionary = {}
	if event is InputEventKey:
		button_data["EventType"] = "InputEventKey"
		button_data["scancode"] = event.scancode
	if event is InputEventJoypadButton:
		button_data["EventType"] = "InputEventJoypadButton"
		button_data["device"] = event.device
		button_data["button_index"] = event.button_index
	if event is InputEventJoypadMotion:
		button_data["EventType"] = "InputEventJoypadMotion"
		button_data["device"] = event.device
		button_data["axis"] = event.axis
		button_data["axis_value"] = event.axis_value
	return button_data


#LOADING CONTROLS
func set_input_data(inputs:Dictionary)->void:
	for action_name in Actions:
		ActionControls[action_name] = []
	var action_names:Array = inputs.keys()
	for action_name in action_names:
		var button_names = inputs[action_name].keys()
		for button_name in button_names:
			var button = inputs[action_name][button_name]
			var event:InputEvent = set_button_data(button)
			ActionControls[action_name].push_back(event)
	set_InputMap()
	set_actions_info()
	
func set_button_data(button:Dictionary)->InputEvent:
	var NewEvent:InputEvent
	if button.EventType == "InputEventKey":
		NewEvent = InputEventKey.new()
		NewEvent.scancode = button.scancode
	if button.EventType == "InputEventJoypadButton":
		NewEvent = InputEventJoypadButton.new()
		NewEvent.device = button.device
		NewEvent.button_index = button.button_index
	if button.EventType == "InputEventJoypadMotion":
		NewEvent = InputEventJoypadMotion.new()
		NewEvent.device = button.device
		NewEvent.axis = button.axis
		NewEvent.axis_value = button.axis_value
	return NewEvent

func set_InputMap()->void:
	for action_name in Actions:
		InputMap.action_erase_events(action_name)
		for event in ActionControls[action_name]:
			InputMap.action_add_event(action_name, event)














