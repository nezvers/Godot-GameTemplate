@tool
extends MarginContainer

## The visual representation of a task.


const __Singletons := preload("../../plugin_singleton/singletons.gd")
const __Shortcuts := preload("../shortcuts.gd")
const __EditContext := preload("../edit_context.gd")
const __Filter := preload("../filter.gd")
const __BoardData := preload("../../data/board.gd")
const __EditLabel := preload("../../edit_label/edit_label.gd")
const __ExpandButton := preload("../../expand_button/expand_button.gd")
const __TaskData := preload("../../data/task.gd")
const __DetailsScript := preload("../details/details.gd")
const __StepHolder := preload("../details/step_holder.gd")
const __TooltipScript := preload("../tooltip.gd")
const __CategoryPopupMenu := preload("../category/category_popup_menu.gd")

enum ACTIONS {
	DETAILS,
	RENAME,
	DELETE,
	DUPLICATE,
}

const COLOR_WIDTH: int = 8

var board_data: __BoardData:
	set(value):
		board_data = value
		__update_category_menu()
var data_uuid: String

var __style_focus: StyleBoxFlat
var __style_panel: StyleBoxFlat

var __category_menu := __CategoryPopupMenu.new()

@onready var panel_container: PanelContainer = %Panel
@onready var category_button: Button = %CategoryButton
@onready var title_label: __EditLabel = %Title
@onready var description_label: Label = %Description
@onready var step_holder: __StepHolder = %StepHolder
@onready var expand_button: __ExpandButton = %ExpandButton
@onready var edit_button: Button = %Edit
@onready var context_menu: PopupMenu = %ContextMenu
@onready var details: __DetailsScript = %Details


func _ready() -> void:
	__style_focus = StyleBoxFlat.new()
	__style_focus.set_border_width_all(1)
	__style_focus.draw_center = false

	__style_panel = StyleBoxFlat.new()
	__style_panel.set_border_width_all(0)
	__style_panel.border_width_left = COLOR_WIDTH
	__style_panel.draw_center = false
	panel_container.add_theme_stylebox_override(&"panel", __style_panel)

	context_menu.id_pressed.connect(__action)
	edit_button.pressed.connect(__action.bind(ACTIONS.DETAILS))
	expand_button.state_changed.connect(func (expanded): __update_step_holder())

	category_button.pressed.connect(__on_category_button_pressed)
	add_child(__category_menu)
	__category_menu.uuid_selected.connect(__on_category_menu_uuid_selected)

	notification(NOTIFICATION_THEME_CHANGED)

	await get_tree().create_timer(0.0).timeout
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)

	update()
	board_data.get_task(data_uuid).changed.connect(update)
	board_data.changed.connect(__update_category_button)

	if data_uuid == ctx.focus:
		ctx.focus = ""
		grab_focus()

	if not ctx.filter_changed.is_connected(__apply_filter):
		ctx.filter_changed.connect(__apply_filter)
		ctx.settings.changed.connect(update)
	__apply_filter()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		__update_context_menu()
		context_menu.position = get_global_mouse_position()
		if not get_window().gui_embed_subwindows:
			context_menu.position += get_window().position
		context_menu.popup()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed() and event.is_double_click():
		__action(ACTIONS.DETAILS)


func _shortcut_input(event: InputEvent) -> void:
	if not __Shortcuts.should_handle_shortcut(self):
		return
	var shortcuts: __Shortcuts = __Singletons.instance_of(__Shortcuts, self)
	if not event.is_echo() and event.is_pressed():
		if shortcuts.delete.matches_event(event):
			get_viewport().set_input_as_handled()
			__action(ACTIONS.DELETE)
		elif shortcuts.confirm.matches_event(event):
			get_viewport().set_input_as_handled()
			__action(ACTIONS.DETAILS)
		elif shortcuts.rename.matches_event(event):
			get_viewport().set_input_as_handled()
			__action(ACTIONS.RENAME)
		elif shortcuts.duplicate.matches_event(event):
			get_viewport().set_input_as_handled()
			__action(ACTIONS.DUPLICATE)


func _make_custom_tooltip(for_text) -> Object:
	var tooltip := __TooltipScript.new()
	tooltip.text = for_text
	tooltip.mimic_paragraphs()
	return tooltip


func _notification(what: int) -> void:
	match(what):
		NOTIFICATION_THEME_CHANGED:
			if panel_container:
				var tab_panel = get_theme_stylebox(&"panel", &"TabContainer")
				if tab_panel is StyleBoxFlat:
					__style_panel.bg_color = tab_panel.bg_color
					__style_panel.draw_center = true
				else:
					__style_panel.draw_center = false
			if edit_button:
				edit_button.icon = get_theme_icon(&"Edit", &"EditorIcons")
		NOTIFICATION_DRAW:
			if has_focus():
				__style_focus.draw(
					get_canvas_item(),
					Rect2(
						panel_container.get_global_rect().position - get_global_rect().position,
						panel_container.size
					),
				)


func update() -> void:
	if not is_inside_tree():
		# The node might linger in the undoredo manager.
		return

	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	var task := board_data.get_task(data_uuid)
	var task_category := board_data.get_category(task.category)

	__style_focus.border_color = task_category.color
	__style_panel.border_color = task_category.color

	category_button.text = task_category.title
	category_button.visible = ctx.settings.show_category_on_board

	if ctx.settings.show_description_preview:
		var description: String
		match ctx.settings.description_on_board:
			ctx.settings.DescriptionOnBoard.FIRST_LINE:
				description = task.description
				var idx := description.find("\n")
				description = description.substr(0, idx)
			ctx.settings.DescriptionOnBoard.UNTIL_FIRST_BLANK_LINE:
				description = task.description
				var idx := description.find("\n\n")
				description = description.substr(0, idx)
			_:
				description = task.description
		description_label.text = description
		if ctx.settings.max_displayed_lines_in_description > 0:
			description_label.max_lines_visible = ctx.settings.max_displayed_lines_in_description
		else:
			description_label.max_lines_visible = -1
		description_label.visible = ctx.settings.show_description_preview and description_label.text.strip_edges().length() != 0
	else:
		description_label.text = ""
	description_label.visible = (description_label.text.length() > 0)

	__update_step_holder()

	var steps := board_data.get_task(data_uuid).steps
	for step in steps:
		if not step.changed.is_connected(__update_step_holder):
			step.changed.connect(__update_step_holder)

	if title_label.text_changed.is_connected(__set_title):
		title_label.text_changed.disconnect(__set_title)
	title_label.text = board_data.get_task(data_uuid).title
	title_label.text_changed.connect(__set_title)

	__update_category_menu()
	__update_category_button()
	__update_tooltip()

	queue_redraw()


func show_edit(intention: __EditLabel.INTENTION) -> void:
	title_label.show_edit(intention)


func __update_step_holder() -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	var task := board_data.get_task(data_uuid)
	var expanded := expand_button.expanded

	step_holder.clear_steps()
	var step_count := 0
	var expandable := false

	if ctx.settings.show_steps_preview:
		var steps := board_data.get_task(data_uuid).steps
		var max_step_count := ctx.settings.max_steps_on_board
		match ctx.settings.steps_on_board:
			ctx.settings.StepsOnBoard.ONLY_OPEN:
				for i in steps.size():
					if steps[i].done:
						continue
					if max_step_count > 0 and step_count >= max_step_count:
						expandable = true
						if not expanded:
							break
					step_holder.add_step(steps[i])
					step_count += 1
			ctx.settings.StepsOnBoard.ALL_OPEN_FIRST:
				for i in steps.size():
					if steps[i].done:
						continue
					if max_step_count > 0 and step_count >= max_step_count:
						expandable = true
						if not expanded:
							break
					step_holder.add_step(steps[i])
					step_count += 1
				for i in steps.size():
					if not steps[i].done:
						continue
					if max_step_count > 0 and step_count >= max_step_count:
						expandable = true
						if not expanded:
							break
					step_holder.add_step(steps[i])
					step_count += 1
			ctx.settings.StepsOnBoard.ALL_IN_ORDER:
				for i in steps.size():
					if max_step_count > 0 and step_count >= max_step_count:
						expandable = true
						if not expanded:
							break
					step_holder.add_step(steps[i])
					step_count += 1
			_:
				pass
	step_holder.visible = (step_count > 0)
	expand_button.visible = expandable


func __update_category_menu() -> void:
	__category_menu.board_data = board_data


func __update_category_button() -> void:
	if board_data.get_category_count() > 1:
		category_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		category_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func __update_tooltip() -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	var task := board_data.get_task(data_uuid)
	var task_category := board_data.get_category(task.category)
	var steps := board_data.get_task(data_uuid).steps

	var category_bullet = "[bgcolor=#" + task_category.color.to_html(false) + "]     [/bgcolor]  "
	#var category_bullet = "[color=#" + task_category.color.to_html(false) + "]\u2588\u2588[/color]"
	#var category_bullet = "[color=#" + task_category.color.to_html(false) + "]\u220E[/color]"
	#var category_bullet = "[color=#" + task_category.color.to_html(false) + "]\u25A0[/color]"
	tooltip_text = category_bullet + " " + board_data.get_category(task.category).title + ": " + task.title
	if task.description !=null and task.description.length() > 0:
		tooltip_text += "[p]" + task.description + "[/p]"

	var open_steps = []
	var done_steps = []
	for step in steps:
		(done_steps if step.done else open_steps).append(step)
	#var open_step_bullet = "\u25A1" # Unfilled square
	#var open_step_bullet = "[color=#808080]\u25A0[/color]" # Filled gray square
	#var done_step_bullet = "\u25A0" # Filled square
	#var open_step_bullet = "\u2718" # Heavy ballot X
	#var done_step_bullet = "\u2714" # Heavy check mark
	#var open_step_bullet = "\u2717" # Ballot X
	#var done_step_bullet = "\u2713" # Check mark
	var open_step_bullet = "[color=#F08080]\u25A0[/color]" # Filled red square
	var done_step_bullet = "[color=#98FB98]\u25A0[/color]" # Filled green square
	if open_steps.size() > 0 or done_steps.size() > 0:
		tooltip_text += "[p]"
		if open_steps.size() > 0:
			tooltip_text += "Open steps:\n[table=2]"
			for step in open_steps:
				tooltip_text += "[cell]" + open_step_bullet + "[/cell][cell]" + step.details + "[/cell]\n"
			tooltip_text += "[/table]\n"
		if done_steps.size() > 0:
			tooltip_text += "Done steps:\n[table=2]"
			for step in done_steps:
				tooltip_text += "[cell]" + done_step_bullet + "[/cell][cell]" + step.details + "[/cell]\n"
			tooltip_text += "[/table]\n"
		tooltip_text += "[/p]"


func __apply_filter() -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)

	if not ctx.filter or ctx.filter.text.length() == 0:
		show()
		return

	var task = board_data.get_task(data_uuid)
	var filter_simple := __simplify_string(ctx.filter.text)
	var filter_matches := false
	if not filter_matches:
		var text_simple := __simplify_string(task.title)
		if text_simple.matchn("*" + filter_simple + "*"):
			filter_matches = true
	if not filter_matches:
		var category = board_data.get_category(task.category)
		var text_simple := __simplify_string(category.title)
		if text_simple.matchn("*" + filter_simple + "*"):
			filter_matches = true
	if not filter_matches and ctx.filter.advanced:
		var text_simple := __simplify_string(task.description)
		if text_simple.matchn("*" + filter_simple + "*"):
			filter_matches = true
	if not filter_matches and ctx.filter.advanced:
		for step in task.steps:
			if not filter_matches:
				var text_simple := __simplify_string(step.details)
				if text_simple.matchn("*" + filter_simple + "*"):
					filter_matches = true
			else:
				break

	if filter_matches:
		show()
	else:
		hide()


func __simplify_string(string: String) -> String:
	return string.replace(" ", "").replace("\t", "")


func __update_context_menu() -> void:
	var shortcuts: __Shortcuts = __Singletons.instance_of(__Shortcuts, self)

	context_menu.clear()
	context_menu.add_item("Details", ACTIONS.DETAILS)

	context_menu.add_separator()

	context_menu.add_icon_item(get_theme_icon(&"Rename", &"EditorIcons"), "Rename", ACTIONS.RENAME)
	context_menu.set_item_shortcut(context_menu.get_item_index(ACTIONS.RENAME), shortcuts.rename)

	context_menu.add_icon_item(get_theme_icon(&"Duplicate", &"EditorIcons"), "Duplicate", ACTIONS.DUPLICATE)
	context_menu.set_item_shortcut(context_menu.get_item_index(ACTIONS.DUPLICATE), shortcuts.duplicate)

	context_menu.add_icon_item(get_theme_icon(&"Remove", &"EditorIcons"), "Delete", ACTIONS.DELETE)
	context_menu.set_item_shortcut(context_menu.get_item_index(ACTIONS.DELETE), shortcuts.delete)


func __action(action) -> void:
	var undo_redo: UndoRedo = __Singletons.instance_of(__EditContext, self).undo_redo

	match(action):
		ACTIONS.DELETE:
			var task = board_data.get_task(data_uuid)
			for uuid in board_data.get_stages():
				var tasks := board_data.get_stage(uuid).tasks
				if data_uuid in tasks:
					tasks.erase(data_uuid)
					undo_redo.create_action("Delete task")
					undo_redo.add_do_property(board_data.get_stage(uuid), &"tasks", tasks)
					undo_redo.add_do_method(board_data.remove_task.bind(data_uuid, true))
					undo_redo.add_undo_method(board_data.__add_task.bind(task, data_uuid))
					undo_redo.add_undo_property(board_data.get_stage(uuid), &"tasks", board_data.get_stage(uuid).tasks)
					undo_redo.add_undo_reference(task)
					undo_redo.commit_action()
					break

		ACTIONS.DETAILS:
			details.board_data = board_data
			details.data_uuid = data_uuid
			details.popup_centered_ratio_no_fullscreen(0.5)

		ACTIONS.DUPLICATE:
			var copy := __TaskData.new()
			copy.from_json(board_data.get_task(data_uuid).to_json())
			var copy_uuid := board_data.add_task(copy)
			for uuid in board_data.get_stages():
				var tasks := board_data.get_stage(uuid).tasks
				if data_uuid in tasks:
					tasks.insert(tasks.find(data_uuid), copy_uuid)
					undo_redo.create_action("Duplicate task")
					undo_redo.add_do_method(board_data.__add_task.bind(copy, copy_uuid))
					undo_redo.add_do_property(board_data.get_stage(uuid), &"tasks", tasks)
					undo_redo.add_undo_property(board_data.get_stage(uuid), &"tasks", board_data.get_stage(uuid).tasks)
					undo_redo.add_undo_method(board_data.remove_task.bind(copy_uuid))
					undo_redo.commit_action(false)

					board_data.get_stage(uuid).tasks = tasks
					break

		ACTIONS.RENAME:
			if context_menu.visible:
				await context_menu.popup_hide
			title_label.show_edit()


func __set_title(value: String) -> void:
	board_data.get_task(data_uuid).title = value


func __on_category_button_pressed() -> void:
	__category_menu.popup_at_local_position(category_button, Vector2(0, category_button.size.y))


func __on_category_menu_uuid_selected(category_uuid) -> void:
	var task = board_data.get_task(data_uuid)
	task.category = category_uuid
