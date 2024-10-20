@tool
extends HBoxContainer

## Visual representation of a category.


const __EditLabel := preload("../../../edit_label/edit_label.gd")
const __BoardData := preload("../../../data/board.gd")
const __Singletons := preload("../../../plugin_singleton/singletons.gd")
const __Shortcuts := preload("../../shortcuts.gd")

var title: __EditLabel
var delete: Button
var color_picker: ColorPickerButton
var focus_box: StyleBoxFlat

var board_data: __BoardData
var data_uuid: String


func _ready() -> void:
	set_h_size_flags(SIZE_EXPAND_FILL)
	focus_mode = FOCUS_ALL
	title = __EditLabel.new()
	title.set_h_size_flags(SIZE_EXPAND_FILL)
	title.text = board_data.get_category(data_uuid).title
	title.text_changed.connect(__on_title_changed)
	add_child(title)

	color_picker = ColorPickerButton.new()
	color_picker.custom_minimum_size.x = 100
	color_picker.edit_alpha = false
	color_picker.color = board_data.get_category(data_uuid).color
	color_picker.focus_mode = Control.FOCUS_NONE
	color_picker.flat = true
	color_picker.popup_closed.connect(__on_color_changed)
	add_child(color_picker)

	delete = Button.new()
	delete.focus_mode = FOCUS_NONE
	delete.flat = true
	delete.disabled = board_data.get_category_count() <= 1
	delete.pressed.connect(__on_delete)
	add_child(delete)

	focus_box = StyleBoxFlat.new()
	focus_box.bg_color = Color(1, 1, 1, 0.1)

	notification(NOTIFICATION_THEME_CHANGED)


func _shortcut_input(event: InputEvent) -> void:
	if not __Shortcuts.should_handle_shortcut(self):
		return
	var shortcuts: __Shortcuts = __Singletons.instance_of(__Shortcuts, self)
	if not event.is_echo() and event.is_pressed():
		if shortcuts.rename.matches_event(event):
			get_viewport().set_input_as_handled()
			title.show_edit()


func _notification(what) -> void:
	match(what):
		NOTIFICATION_THEME_CHANGED:
			if is_instance_valid(delete):
				delete.icon = get_theme_icon(&"Remove", &"EditorIcons")
		NOTIFICATION_DRAW:
			if has_focus():
				focus_box.draw(get_canvas_item(), Rect2(Vector2.ZERO, get_rect().size))


func show_edit(intention: int = title.default_intention) -> void:
	title.show_edit(intention)


func __on_title_changed(new: String) -> void:
	board_data.get_category(data_uuid).title = new


func __on_color_changed() -> void:
	board_data.get_category(data_uuid).color = color_picker.color
	# Hack to get the tasks to update their color.
	board_data.layout.changed.emit()


func __on_delete() -> void:
	board_data.remove_category(data_uuid)

	var fallback_to = board_data.get_categories()[0]
	for uuid in board_data.get_tasks():
		if board_data.get_task(uuid).category == data_uuid:
			board_data.get_task(uuid).category = fallback_to

	get_parent().get_owner().update()
