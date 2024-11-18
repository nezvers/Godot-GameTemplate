extends ColorRect

@export var button_list:Array[BindingButton]
## Choice button parent. Used for toggling visibility.
@export var choice_button_group:Control
## Label to show information abouut listening on users input
@export var info_label:Label
@export var focus_button:Button
@export var new_button:Button
@export var delete_button:Button
@export var cancel_button:Button
@export var back_button:Button

var current_button:BindingButton
enum ChoiceType{NEW, DELETE, CANCEL}

func _ready()->void:
	visible = false
	set_process_input(false)
	new_button.pressed.connect(_on_choice.bind(ChoiceType.NEW))
	delete_button.pressed.connect(_on_choice.bind(ChoiceType.DELETE))
	cancel_button.pressed.connect(_on_choice.bind(ChoiceType.CANCEL))
	
	for _button:BindingButton in button_list:
		_button.pressed.connect(_on_button.bind(_button))

## Calback on BindingButton pressed signal
func _on_button(button:BindingButton)->void:
	current_button = button
	_open()
	new_button.grab_focus.call_deferred()

## Reacts on users choice
func _on_choice(choice:ChoiceType)->void:
	match choice:
		ChoiceType.CANCEL:
			_close()
			current_button.grab_focus.call_deferred()
		ChoiceType.DELETE:
			_close()
			current_button.change_binding(null)
			current_button.grab_focus.call_deferred()
		ChoiceType.NEW:
			info_label.visible = true
			choice_button_group.visible = false
			set_process_input(true)

## Shows panel and disables focus ability for binding buttons
func _open()->void:
	visible = true
	choice_button_group.visible = true
	info_label.visible = false
	back_button.focus_mode = Control.FOCUS_NONE
	for _button:BindingButton in button_list:
		_button.focus_mode = Control.FOCUS_NONE

## Hides panel and enables focus ability for binding buttons
func _close()->void:
	set_process_input(false)
	visible = false
	choice_button_group.visible = true
	info_label.visible = false
	back_button.focus_mode = Control.FOCUS_ALL
	for _button:BindingButton in button_list:
		_button.focus_mode = Control.FOCUS_ALL

## Listening to inputs when user choses to change to a new input
func _input(event:InputEvent)->void:
	if !event.is_released():
		return
	match current_button.type:
		BindingButton.EventType.KEYBOARD:
			if event is InputEventKey:
				current_button.change_binding.call_deferred(event)
				_close()
				current_button.grab_focus.call_deferred()
				return
			if event is InputEventMouseButton:
				current_button.change_binding.call_deferred(event)
				_close()
				current_button.grab_focus.call_deferred()
				return
		BindingButton.EventType.GAMEPAD:
			if event is InputEventJoypadButton:
				current_button.change_binding.call_deferred(event)
				_close()
				current_button.grab_focus.call_deferred()
				return
			if event is InputEventJoypadMotion:
				current_button.change_binding.call_deferred(event)
				_close()
				current_button.grab_focus.call_deferred()
				return
