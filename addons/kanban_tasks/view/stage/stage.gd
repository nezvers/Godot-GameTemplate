@tool
extends MarginContainer

## The visual representation of a stage.


const __Singletons := preload("../../plugin_singleton/singletons.gd")
const __Shortcuts := preload("../shortcuts.gd")
const __EditContext := preload("../edit_context.gd")
const __TaskData := preload("../../data/task.gd")
const __TaskScene := preload("../task/task.tscn")
const __TaskScript := preload("../task/task.gd")
const __EditLabel := preload("../../edit_label/edit_label.gd")
const __BoardData := preload("../../data/board.gd")
const __CategoryPopupMenu := preload("../category/category_popup_menu.gd")

var board_data: __BoardData
var data_uuid: String

var __category_menu := __CategoryPopupMenu.new()

@onready var panel_container: PanelContainer = %Panel
@onready var title_label: __EditLabel = %Title
@onready var create_button: Button = %Create
@onready var task_holder: VBoxContainer = %TaskHolder
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var preview: Control = %Preview
@onready var preview_color: ColorRect = %Preview/Color


func _ready() -> void:
	update()
	board_data.get_stage(data_uuid).changed.connect(update.bind(true))

	scroll_container.set_drag_forwarding(
		_get_drag_data_fw.bind(scroll_container),
		_can_drop_data_fw.bind(scroll_container),
		_drop_data_fw.bind(scroll_container),
	)

	create_button.pressed.connect(__on_create_button_pressed)
	add_child(__category_menu)
	__category_menu.uuid_selected.connect(__on_category_create_popup_uuid_selected)
	__category_menu.popup_hide.connect(create_button.set_pressed_no_signal.bind(false))

	notification(NOTIFICATION_THEME_CHANGED)

	await get_tree().create_timer(0.0).timeout
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	if ctx.focus == data_uuid:
		ctx.focus = ""
		grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not Rect2(Vector2(), size).has_point(get_local_mouse_position()):
			preview.visible = false


func _shortcut_input(event: InputEvent) -> void:
	if not __Shortcuts.should_handle_shortcut(self):
		return
	var shortcuts: __Shortcuts = __Singletons.instance_of(__Shortcuts, self)
	if not event.is_echo() and event.is_pressed():
		if shortcuts.create.matches_event(event):
			get_viewport().set_input_as_handled()

			__category_menu.popup_at_mouse_position(self)

		elif shortcuts.rename.matches_event(event):
			get_viewport().set_input_as_handled()
			title_label.show_edit()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	preview.visible = true
	preview.position.y = __target_height_from_position(at_position)

	return data is Dictionary and data.has("task") and data.has("stage")


func _can_drop_data_fw(at_position: Vector2, data: Variant, from: Control) -> bool:
	var local_pos = (at_position + from.get_global_rect().position) - get_global_rect().position
	return _can_drop_data(local_pos, data)


func _get_drag_data_fw(at_position: Vector2, from: Control) -> Variant:
	if from is __TaskScript:
		var control := Control.new()
		var rect := ColorRect.new()
		control.add_child(rect)
		rect.size = from.get_rect().size
		rect.position = -at_position
		rect.color = board_data.get_category(board_data.get_task(from.data_uuid).category).color
		from.set_drag_preview(control)

		return {
			"task": from.data_uuid,
			"stage": data_uuid,
		}
	return null


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var index := __target_index_from_position(at_position)
	preview.hide()

	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	ctx.undo_redo.create_action("Move task")

	var tasks := board_data.get_stage(data["stage"]).tasks

	if data["stage"] == data_uuid:
		var old_index := tasks.find(data["task"])
		if index < old_index:
			tasks.erase(data["task"])
			tasks.insert(index, data["task"])
		elif index > old_index + 1:
			tasks.erase(data["task"])
			tasks.insert(index - 1, data["task"])
	else:
		tasks.erase(data["task"])

		ctx.undo_redo.add_do_property(board_data.get_stage(data["stage"]), &"tasks", tasks.duplicate())
		ctx.undo_redo.add_undo_property(board_data.get_stage(data["stage"]), &"tasks", board_data.get_stage(data["stage"]).tasks)

		tasks = board_data.get_stage(data_uuid).tasks
		tasks.insert(index, data["task"])

	ctx.focus = data["task"]

	ctx.undo_redo.add_do_property(board_data.get_stage(data_uuid), &"tasks", tasks)
	ctx.undo_redo.add_undo_property(board_data.get_stage(data_uuid), &"tasks", board_data.get_stage(data_uuid).tasks)
	ctx.undo_redo.commit_action()


func _drop_data_fw(at_position: Vector2, data: Variant, from: Control) -> void:
	var local_pos = (at_position + from.get_global_rect().position) - get_global_rect().position
	_drop_data(local_pos, data)


func _notification(what: int) -> void:
	match(what):
		NOTIFICATION_THEME_CHANGED:
			if is_instance_valid(panel_container):
				panel_container.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"panel", &"Tree"))
			if is_instance_valid(create_button):
				create_button.icon = get_theme_icon(&"Add", &"EditorIcons")
			if is_instance_valid(preview_color):
				preview_color.color = get_theme_color(&"font_selected_color", &"TabBar")


func update(single: bool = false) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if single:
		grab_focus()

	if title_label.text_changed.is_connected(__set_title):
		title_label.text_changed.disconnect(__set_title)
	title_label.text = board_data.get_stage(data_uuid).title
	title_label.text_changed.connect(__set_title)

	var old_scroll := scroll_container.scroll_vertical

	if is_instance_valid(focus_owner) and (is_ancestor_of(focus_owner) or focus_owner == self):
		if focus_owner is __TaskScript:
			__Singletons.instance_of(__EditContext, self).focus = focus_owner.data_uuid

	for task in task_holder.get_children():
		task.queue_free()

	for uuid in board_data.get_stage(data_uuid).tasks:
		var task: __TaskScript = __TaskScene.instantiate()
		task.board_data = board_data
		task.data_uuid = uuid
		task.set_drag_forwarding(
			_get_drag_data_fw.bind(task),
			_can_drop_data_fw.bind(task),
			_drop_data_fw.bind(task),
		)
		task_holder.add_child(task)

	scroll_container.scroll_vertical = old_scroll
	__update_category_menus()


func __update_category_menus() -> void:
	__category_menu.board_data = board_data


func __target_index_from_position(pos: Vector2) -> int:
	var global_pos := pos + get_global_position()

	if not scroll_container.get_global_rect().has_point(global_pos):
		return 0

	var scroll_pos := global_pos - task_holder.get_global_position()
	var c := 0
	for task in task_holder.get_children():
		var y = task.position.y + task.size.y/2
		if scroll_pos.y < y:
			return c
		c += 1

	return task_holder.get_child_count()


func __set_title(value: String) -> void:
	board_data.get_stage(data_uuid).title = value


func __on_create_button_pressed() -> void:
	if board_data.get_category_count() > 1:
		__category_menu.popup_at_local_position(create_button, Vector2(0, create_button.get_global_rect().size.y))
	else:
		__create_task(board_data.get_categories()[0])
		create_button.set_pressed_no_signal(false)


func __create_task(category: String) -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	var stage_data := board_data.get_stage(data_uuid)

	var task_data := __TaskData.new("New task", "", category)
	var uuid = board_data.add_task(task_data)
	var tasks = stage_data.tasks
	tasks.append(uuid)

	ctx.undo_redo.create_action("Add task")
	ctx.undo_redo.add_do_method(board_data.__add_task.bind(task_data, uuid))
	ctx.undo_redo.add_do_property(stage_data, &"tasks", tasks)
	ctx.undo_redo.add_undo_property(stage_data, &"tasks", stage_data.tasks)
	ctx.undo_redo.add_undo_method(board_data.remove_task.bind(uuid))
	ctx.undo_redo.commit_action(false)

	stage_data.tasks = tasks

	for task in task_holder.get_children():
		if task.data_uuid == uuid:
			await get_tree().create_timer(0.0).timeout
			task.grab_focus()
			task.show_edit(__EditLabel.INTENTION.REPLACE)

	ctx.filter = null


func __target_height_from_position(pos: Vector2) -> float:
	var global_pos = pos + get_global_position()

	if not scroll_container.get_global_rect().has_point(global_pos):
		return - float(task_holder.get_theme_constant(&"separation")) / 2.0

	var scroll_pos: Vector2 = global_pos - task_holder.get_global_position()
	var c := 0.0
	for task in task_holder.get_children():
		var y = task.position.y + task.size.y/2.0
		if scroll_pos.y < y:
			return c - float(task_holder.get_theme_constant(&"separation")) / 2.0
		c += task.size.y + task_holder.get_theme_constant(&"separation")

	return c


func __on_category_create_popup_uuid_selected(uuid) -> void:
	__create_task(uuid)
