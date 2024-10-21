@tool
extends HBoxContainer

## Visual representation of a step.


signal action_triggered(entry: __StepEntry, action: Actions)

const __EditLabel := preload("../../edit_label/edit_label.gd")
const __StepData := preload("../../data/step.gd")
const __Singletons := preload("../../plugin_singleton/singletons.gd")
const __Shortcuts := preload("../shortcuts.gd")
const __StepEntry := preload("step_entry.gd")

enum Actions {
	DELETE,
	MOVE_UP,
	MOVE_DOWN,
	EDIT_HARD, ## Forces the step details to open.
	EDIT_SOFT, ## Only switches to this step if the details are opened.
	CLOSE,
}

@export var context_menu_enabled: bool = true

var done: CheckBox
var title_label: Label
var focus_box: StyleBoxFlat
var context_menu: PopupMenu

var step_data: __StepData

var being_edited := false


func _ready() -> void:
	set_h_size_flags(SIZE_EXPAND_FILL)

	context_menu = PopupMenu.new()
	context_menu.id_pressed.connect(__action)
	add_child(context_menu)

	done = CheckBox.new()
	done.focus_mode = Control.FOCUS_NONE
	done.toggled.connect(__set_done)
	add_child(done)

	title_label = Label.new()
	title_label.set_h_size_flags(SIZE_EXPAND_FILL)
	title_label.text = step_data.details
	title_label.max_lines_visible = 1
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(title_label)

	focus_box = StyleBoxFlat.new()
	focus_box.bg_color = Color(1, 1, 1, 0.1)

	notification(NOTIFICATION_THEME_CHANGED)

	step_data.changed.connect(update)
	update()


func _shortcut_input(event: InputEvent) -> void:
	if not __Shortcuts.should_handle_shortcut(self):
		return
	var shortcuts: __Shortcuts = __Singletons.instance_of(__Shortcuts, self)
	if not event.is_echo() and event.is_pressed():
		if shortcuts.rename.matches_event(event):
			get_viewport().set_input_as_handled()
			__action(Actions.EDIT_HARD)
		elif shortcuts.confirm.matches_event(event):
			get_viewport().set_input_as_handled()
			done.button_pressed = not done.button_pressed


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		if context_menu_enabled:
			__update_context_menu()
			context_menu.position = get_global_mouse_position()
			if not get_window().gui_embed_subwindows:
				context_menu.position += get_window().position
			context_menu.popup()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed() and event.is_double_click():
		__action(Actions.EDIT_HARD)


func _notification(what) -> void:
	match(what):
		NOTIFICATION_DRAW:
			if has_focus() or being_edited:
				focus_box.draw(get_canvas_item(), Rect2(Vector2.ZERO, get_rect().size))
		NOTIFICATION_FOCUS_ENTER:
			__action(Actions.EDIT_SOFT)


func update() -> void:
	tooltip_text = step_data.details
	done.set_pressed_no_signal(step_data.done)

	title_label.text = step_data.details


func __action(what: Actions) -> void:
	action_triggered.emit(self, what)


func __update_context_menu() -> void:
	var shortcuts: __Shortcuts = __Singletons.instance_of(__Shortcuts, self)

	context_menu.clear()
	context_menu.size = Vector2.ZERO

	if being_edited:
		context_menu.add_icon_item(get_theme_icon(&"Close", &"EditorIcons"), "Close", Actions.CLOSE)
	else:
		context_menu.add_icon_item(get_theme_icon(&"Rename", &"EditorIcons"), "Edit", Actions.EDIT_HARD)
		context_menu.set_item_shortcut(context_menu.get_item_index(Actions.EDIT_HARD), shortcuts.rename)

	context_menu.add_icon_item(get_theme_icon(&"MoveUp", &"EditorIcons"), "Move Up", Actions.MOVE_UP)
	context_menu.set_item_disabled(context_menu.get_item_index(Actions.MOVE_UP), get_index() == 0)
	context_menu.add_icon_item(get_theme_icon(&"MoveDown", &"EditorIcons"), "Move Down", Actions.MOVE_DOWN)
	context_menu.set_item_disabled(context_menu.get_item_index(Actions.MOVE_DOWN), get_index() == get_parent().get_child_count() - 1)

	context_menu.add_separator()

	context_menu.add_icon_item(get_theme_icon(&"Remove", &"EditorIcons"), "Delete", Actions.DELETE)


func __set_done(done: bool) -> void:
	__action(Actions.CLOSE)
	step_data.done = done
