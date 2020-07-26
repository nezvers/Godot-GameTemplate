extends Node


#CONTROLS
var Actions:Array = ["Right", "Left", "Up", "Down", "Jump"]
var ActionControls:Dictionary = {}

#CONTROLS
func get_controls()->void:
	if !SettingsSaveLoad.Settings_loaded:
		default_controls()
	set_actions_info()

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
