@tool
extends VBoxContainer

## A label with editable content.
##
## While not editing the text is displayed in a label. So it does not stick out
## of some layout to much. Only while editing the label it is replaced with an
## line edit.
## Click onto the label to start editing it or start the editing mode via code
## by using [member show_edit]. When editing press [kbd]Enter[/kbd] to finish
## editing or press [kbd]Esc[/kbd] to discard your changes.


## Emitted when the text changed.
##
## [b]Note:[/b] This is only emitted when you confirm your editing by pressing
## [kbd]Enter[/kbd]. If you need access to all changes while editing use the
## line edit directly. You can get it by calling [method get_edit].
signal text_changed(new_text: String)

## The intentions with which the label can be edited.
enum INTENTION {
	REPLACE,	## The text will be marked completly when editing.
	ADDITION,	## The cursor is placed at the end when editing.
}

## The text to display and edit.
@export var text: String = "":
	set(value):
		text = value
		__update_content()
		text_changed.emit(text)

## The default intention when editing the [member text].
@export var default_intention := INTENTION.ADDITION

## Whether a double click is needed for editing. If [code]false[/code] a single
## click is enough.
@export var double_click: bool = true

# The line edit which is used to edit the text.
var __edit: LineEdit

# The label which is used to display the text.
var __label: Label

# The node which had focus before editing started. Used
# to give focus back to it, when [kbd]Enter[/kbd] is used.
var __old_focus: Control = null


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Setup the internal label.
	__label = Label.new()
	__label.size_flags_horizontal = SIZE_EXPAND_FILL
	__label.size_flags_vertical = SIZE_SHRINK_CENTER
	__label.mouse_filter = Control.MOUSE_FILTER_PASS

	__label.clip_text = true
	__label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	__label.gui_input.connect(__on_label_gui_input)
	add_child(__label)

	# Setup the internal line edit.
	__edit = LineEdit.new()
	__edit.visible = false
	__edit.size_flags_horizontal = SIZE_EXPAND_FILL
	__edit.size_flags_vertical = SIZE_FILL
	__edit.text_submitted.connect(__on_edit_text_submitted)
	__edit.gui_input.connect(__on_edit_gui_input)
	__edit.focus_exited.connect(__on_edit_focus_exited, CONNECT_DEFERRED)
	add_child(__edit)

	__update_content()

	# Wait for the label to get its true size.
	await get_tree().create_timer(0.0).timeout
	# Keep the same size when changing the edit mode.
	custom_minimum_size.y = max(__label.size.y, __edit.size.y) * 1.1


func _input(event: InputEvent) -> void:
	# End the editing when somewhere else was clicked.
	if (event is InputEventMouseButton) and event.pressed and __edit.visible:
		var local = __edit.make_input_local(event)
		if not Rect2(Vector2.ZERO, __edit.size).has_point(local.position):
			show_label()


## Start editing the text and pass an optional intention.
## This can be used to open the edit interface via code.
func show_edit(intention: INTENTION = default_intention) -> void:
	if __edit.visible:
		return

	# When this node can grab focus the focus should not be given back to the
	# old focus owner.
	__old_focus = get_viewport().gui_get_focus_owner() if focus_mode == FOCUS_NONE else null

	__update_content()
	__label.visible = false
	__edit.visible = true

	__edit.grab_focus()

	match intention:
		INTENTION.ADDITION:
			__edit.caret_column = len(__edit.text)
		INTENTION.REPLACE:
			__edit.select_all()


## Ends editing. If [code]apply_changes[/code] is [code]true[/code] the changed
## text will be applied to the own [member text]. Otherwise the changes will
## be discarded.
func show_label(apply_changes: bool = true) -> void:
	if __label.visible:
		return

	if apply_changes:
		text = __edit.text

	if is_instance_valid(__old_focus):
		__old_focus.grab_focus()
	else:
		if focus_mode == FOCUS_NONE:
			__edit.release_focus()
		else:
			grab_focus()

	__edit.visible = false
	__label.visible = true


## Returns the [LineEdit] used to edit the text.
##
## [b]Warning:[/b] This is a required internal node, romoving and freeing it
## may cause a crash. Feel free to edit its parameters to change, how the
## [member text] is displayed.
func get_edit() -> LineEdit:
	return __edit


## Returns the [Label] used display the text.
##
## [b]Warning:[/b] This is a required internal node, romoving and freeing it
## may cause a crash. Feel free to edit its parameters to change, how the
## [member text] is displayed.
func get_label() -> Label:
	return __label


# Updates the diplayed text of [member __edit] and
# [member __label] based on [member text].
func __update_content() -> void:
	if __label:
		__label.text = text
	if __edit:
		__edit.text = text


func __on_label_gui_input(event: InputEvent) -> void:
	# Edit when the label is clicked.
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			if double_click == event.is_double_click():
				# Mark event as handled.
				__label.accept_event()
				show_edit()


func __on_edit_gui_input(event: InputEvent) -> void:
	# Discard changes if ui_cancel action is pressed.
	if event is InputEventKey and event.is_pressed():
		if event.is_action(&"ui_cancel"):
			show_label(false)


func __on_edit_text_submitted(_new_text: String) -> void:
	# For some reason line edit does not accept the event on its own in GD4.
	__edit.accept_event()
	show_label()


func __on_edit_focus_exited() -> void:
	if __edit.visible:
		__old_focus = null
		show_label()
