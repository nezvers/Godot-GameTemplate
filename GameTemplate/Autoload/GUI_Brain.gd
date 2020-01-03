extends Node

###Probably all GUI controlling functions will be there to separate mixing functions

var FocusGroup:Array
var ButtonsSections:Dictionary = {}

func _ready()->void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process_unhandled_key_input(true)
	Event.connect("Refocus", self, "force_focus")

func gui_collect_focusgroup()->void:
	FocusGroup.clear()
	FocusGroup = get_tree().get_nodes_in_group("FocusGroup")
	for btn in FocusGroup: #Save references to call main buttons in sections
		var groups:Array = btn.get_groups()
		if groups.has("MainMenu"):
			ButtonsSections["MainMenu"] = btn
		if groups.has("Pause"):
			ButtonsSections["Pause"] = btn
		if groups.has("OptionsMain"):
			ButtonsSections["OptionsMain"] = btn
		if groups.has("OptionsControls"):
			ButtonsSections["OptionsControls"] = btn

func _unhandled_input(event)->void: #For some reasons works great for starting focus
	if event.is_action_pressed("ui_right"):
		Event.emit_signal("Refocus")
	elif event.is_action_pressed("ui_left"):
		Event.emit_signal("Refocus")
	elif event.is_action_pressed("ui_up"):
		Event.emit_signal("Refocus")
	elif event.is_action_pressed("ui_down"):
		Event.emit_signal("Refocus")

func force_focus():
	var btn:Button
	if Event.MainMenu:
		if Event.Options:
			if Event.Controls:
				btn = ButtonsSections.OptionsControls
			else:
				btn = ButtonsSections.OptionsMain
		else:
			btn = ButtonsSections.MainMenu
	else:
		if Event.Options:
			if Event.Controls:
				btn = ButtonsSections.OptionsControls
			else:
				btn = ButtonsSections.OptionsMain
		else:
			btn = ButtonsSections.Pause
	if btn != null:
		btn.grab_focus()