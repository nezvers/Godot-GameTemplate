@tool
extends "standalone_plugin.gd"


const __Singletons := preload("./plugin_singleton/singletons.gd")
const __Shortcuts := preload("./view/shortcuts.gd")
const __EditContext := preload("./view/edit_context.gd")
const __Settings := preload("./data/settings.gd")
const __BoardData := preload("./data/board.gd")
const __LayoutData := preload("./data/layout.gd")
const __TaskData := preload("./data/task.gd")
const __CategoryData := preload("./data/category.gd")
const __StageData := preload("./data/stage.gd")
const __BoardView := preload("./view/board/board.tscn")
const __BoardViewType := preload("./view/board/board.gd")
const __StartView := preload("./view/start/start.tscn")
const __StartViewType := preload("./view/start/start.gd")
const __DocumentationView := preload("./view/documentation/documentation.tscn")

const SETTINGS_KEY: String = "kanban_tasks/general/settings"

enum {
	ACTION_SAVE,
	ACTION_SAVE_AS,
	ACTION_OPEN,
	ACTION_CREATE,
	ACTION_CLOSE,
	ACTION_DOCUMENTATION,
	ACTION_QUIT,
}

var main_panel_frame: MarginContainer
var start_view: __StartViewType
var file_dialog_save: FileDialog
var file_dialog_open: FileDialog
var discard_changes_dialog: ConfirmationDialog
var documentation_dialog: AcceptDialog

var file_menu: PopupMenu
var help_menu: PopupMenu

var board_view: __BoardViewType
var board_label: Label
var board_path: String = "":
	set(value):
		board_path = value
		__update_board_label()
		__update_menus()
var board_changed: bool = false:
	set(value):
		board_changed = value
		__update_board_label()


func _enter_tree() -> void:
	board_label = Label.new()
	if not Engine.is_editor_hint():
		add_control_to_container(CONTAINER_TOOLBAR, board_label)

	file_menu = PopupMenu.new()
	file_menu.name = "File"
	file_menu.add_item("Save board", ACTION_SAVE)
	file_menu.add_item("Save board as...", ACTION_SAVE_AS)
	file_menu.add_item("Close board", ACTION_CLOSE)
	file_menu.add_item("Open board...", ACTION_OPEN)
	file_menu.add_item("Create board", ACTION_CREATE)
	file_menu.add_separator()
	file_menu.add_item("Quit", ACTION_QUIT)
	file_menu.id_pressed.connect(__action)
	add_menu(file_menu)

	help_menu = PopupMenu.new()
	help_menu.name = "Help"
	help_menu.add_item("Documentation", ACTION_DOCUMENTATION)
	help_menu.id_pressed.connect(__action)
	add_menu(help_menu)

	file_dialog_save = FileDialog.new()
	file_dialog_save.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog_save.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog_save.add_filter("*.kanban, *.json", "Kanban Board")
	file_dialog_save.min_size = Vector2(800, 500)
	file_dialog_save.file_selected.connect(__save_board)
	get_editor_interface().get_base_control().add_child(file_dialog_save)

	file_dialog_open = FileDialog.new()
	file_dialog_open.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog_open.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog_open.add_filter("*.kanban, *.json", "Kanban Board")
	file_dialog_open.min_size = Vector2(800, 500)
	file_dialog_open.file_selected.connect(__open_board)
	get_editor_interface().get_base_control().add_child(file_dialog_open)

	discard_changes_dialog = ConfirmationDialog.new()
	discard_changes_dialog.dialog_text = "All unsaved changes will be discarded."
	discard_changes_dialog.unresizable = true
	get_editor_interface().get_base_control().add_child(discard_changes_dialog)

	documentation_dialog = __DocumentationView.instantiate()
	get_editor_interface().get_base_control().add_child(documentation_dialog)

	main_panel_frame = MarginContainer.new()
	main_panel_frame.add_theme_constant_override(&"margin_top", 5)
	main_panel_frame.add_theme_constant_override(&"margin_left", 5)
	main_panel_frame.add_theme_constant_override(&"margin_bottom", 5)
	main_panel_frame.add_theme_constant_override(&"margin_right", 5)
	main_panel_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	get_editor_interface().get_editor_main_screen().add_child(main_panel_frame)

	start_view = __StartView.instantiate()
	start_view.create_board.connect(__action.bind(ACTION_CREATE))
	start_view.open_board.connect(__on_start_view_open_board)
	main_panel_frame.add_child(start_view)

	_make_visible(false)

	await get_tree().create_timer(0.0).timeout

	__load_settings()

	if Engine.is_editor_hint():
		var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
		var editor_data_file_path = ctx.settings.editor_data_file_path
		if FileAccess.file_exists(editor_data_file_path):
			__open_board(editor_data_file_path)
		elif FileAccess.file_exists("res://addons/kanban_tasks/data.json"):
			# TODO: Remove sometime in the future.
			# Migrate from old version.
			__open_board("res://addons/kanban_tasks/data.json")
			__save_board(editor_data_file_path)
		else:
			__create_board()
			__save_board(editor_data_file_path)

	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	ctx.save_board.connect(__editor_save_board)
	ctx.reload_board.connect(__editor_reload_board)
	ctx.create_board.connect(__editor_create_board)

	__update_menus()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		remove_control_from_container(CONTAINER_TOOLBAR, board_label)
	board_label.queue_free()

	remove_menu(file_menu)
	file_menu.queue_free()

	remove_menu(help_menu)
	file_menu.queue_free()

	file_dialog_save.queue_free()
	file_dialog_open.queue_free()
	discard_changes_dialog.queue_free()
	documentation_dialog.queue_free()

	main_panel_frame.queue_free()
	start_view.queue_free()

	if is_instance_valid(board_view):
		board_view.queue_free()


func _shortcut_input(event: InputEvent) -> void:
	var shortcuts: __Shortcuts = __Singletons.instance_of(__Shortcuts, self)
	if not Engine.is_editor_hint() and shortcuts.save.matches_event(event):
		get_viewport().set_input_as_handled()
		__action(ACTION_SAVE)

	if not Engine.is_editor_hint() and shortcuts.save_as.matches_event(event):
		get_viewport().set_input_as_handled()
		__action(ACTION_SAVE_AS)


func _has_main_screen() -> bool:
	return true


func _make_visible(visible) -> void:
	if main_panel_frame:
		main_panel_frame.visible = visible


func _get_plugin_name() -> String:
	return "Tasks"


func _get_plugin_icon() -> Texture2D:
	return preload("./icon.svg")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if not Engine.is_editor_hint():
				if not board_changed:
					get_tree().quit()
				else:
					__request_discard_changes(get_tree().quit)


func __update_menus() -> void:
	if not is_instance_valid(file_menu):
		return

	var shortcuts: __Shortcuts = __Singletons.instance_of(__Shortcuts, self)

	file_menu.set_item_disabled(
		file_menu.get_item_index(ACTION_SAVE),
		not is_instance_valid(board_view),
	)
	file_menu.set_item_shortcut(
		file_menu.get_item_index(ACTION_SAVE),
		shortcuts.save,
	)
	file_menu.set_item_disabled(
		file_menu.get_item_index(ACTION_SAVE_AS),
		not is_instance_valid(board_view),
	)
	file_menu.set_item_shortcut(
		file_menu.get_item_index(ACTION_SAVE_AS),
		shortcuts.save_as,
	)
	file_menu.set_item_disabled(
		file_menu.get_item_index(ACTION_CLOSE),
		not is_instance_valid(board_view),
	)


func __update_board_label() -> void:
	if not is_instance_valid(board_label):
		return
	if is_instance_valid(board_view):
		if board_path.is_empty():
			board_label.text = "unsaved"
		else:
			board_label.text = board_path
		if board_changed:
			board_label.text += "*"
	else:
		board_label.text = ""


func __action(id: int) -> void:
	match id:
		ACTION_SAVE:
			__request_save()
		ACTION_SAVE_AS:
			__request_save(true)
		ACTION_CREATE:
			if not board_changed:
				__create_board()
			else:
				__request_discard_changes(__create_board)
		ACTION_OPEN:
			if not board_changed:
				file_dialog_open.popup_centered()
			else:
				__request_discard_changes(file_dialog_open.popup_centered)
		ACTION_CLOSE:
			if not board_changed:
				__close_board()
			else:
				__request_discard_changes(__close_board)
		ACTION_DOCUMENTATION:
			documentation_dialog.popup_centered()
		ACTION_QUIT:
			get_tree().get_root().propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


func __editor_save_board() -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	__save_board(ctx.settings.editor_data_file_path)


func __editor_reload_board() -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	__action(ACTION_SAVE)
	__open_board(ctx.settings.editor_data_file_path)


func __editor_create_board() -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	__action(ACTION_SAVE)
	__create_board()
	__save_board(ctx.settings.editor_data_file_path)


func __request_discard_changes(callback: Callable) -> void:
	for connection in discard_changes_dialog.confirmed.get_connections():
		discard_changes_dialog.confirmed.disconnect(connection["callable"])
	discard_changes_dialog.confirmed.connect(callback)
	discard_changes_dialog.popup_centered()


func __request_save(force_new_location: bool = false) -> void:
	if not is_instance_valid(board_view):
		return
	if not force_new_location and not board_path.is_empty():
		__save_board(board_path)
	else:
		file_dialog_save.popup_centered()


func __create_board() -> void:
	var data := __BoardData.new()

	data.layout = __LayoutData.new([
		PackedStringArray([data.add_stage(__StageData.new("Todo"))]),
		PackedStringArray([data.add_stage(__StageData.new("Doing"))]),
		PackedStringArray([data.add_stage(__StageData.new("Done"))]),
	])
	data.add_category(
		__CategoryData.new(
			"Task",
			get_editor_interface().get_base_control().
			get_theme_color(&"accent_color", &"Editor")
		)
	)

	data.changed.connect(__on_board_changed)

	__make_board_view_visible(data)

	board_path = ""
	board_changed = false


func __save_board(path: String) -> void:
	if is_instance_valid(board_view):
		__add_to_recent_files(path)
		board_path = path
		board_view.board_data.save(path)
		board_changed = false


func __open_board(path: String) -> void:
	var data := __BoardData.new()
	data.load(path)
	data.changed.connect(__on_board_changed)

	__make_board_view_visible(data)
	__add_to_recent_files(path)

	board_path = path
	board_changed = false


func __close_board() -> void:
	board_view.queue_free()
	board_view = null
	board_path = ""
	board_changed = false
	start_view.show()


func __add_to_recent_files(path: String) -> void:
	if Engine.is_editor_hint():
		return

	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	var files = ctx.settings.recent_files

	if path in files:
		files.remove_at(files.find(path))
		files.insert(0, path)
	else:
		files.insert(0, path)
		files.resize(ctx.settings.recent_file_count)

	ctx.settings.recent_files = files


func __on_board_changed() -> void:
	board_changed = true
	if Engine.is_editor_hint():
		__request_save()


func __on_start_view_open_board(path: String) -> void:
	if path.is_empty():
		__action(ACTION_OPEN)
	else:
		__open_board(path)


func __make_board_view_visible(data: __BoardData) -> void:
	if is_instance_valid(board_view):
		board_view.queue_free()
	board_view = __BoardView.instantiate()
	board_view.show_documentation.connect(__action.bind(ACTION_DOCUMENTATION))
	board_view.board_data = data

	main_panel_frame.add_child(board_view)
	start_view.hide()


func __save_settings() -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	var data := JSON.stringify(ctx.settings.to_json())
	if Engine.is_editor_hint():
		get_editor_interface().get_editor_settings().set_setting(
			SETTINGS_KEY,
			data,
		)
	else:
		ProjectSettings.set_setting(
			SETTINGS_KEY,
			data,
		)
		save_project_settings()


func __load_settings() -> void:
	var data: String = "{}"
	if Engine.is_editor_hint():
		var editor_settings = get_editor_interface().get_editor_settings()
		if editor_settings.has_setting(SETTINGS_KEY):
			data = editor_settings.get_setting(SETTINGS_KEY)
	else:
		if ProjectSettings.has_setting(SETTINGS_KEY):
			data = ProjectSettings.get_setting(SETTINGS_KEY)

	var json = JSON.new()
	var err = json.parse(data)
	if err != OK:
		push_error(
			"Error "
			+ str(err)
			+ " while parsing settings. At line "
			+ str(json.get_error_line())
			+ " the following problem occured:\n"
			+ json.get_error_message()
		)
		return

	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	ctx.settings.from_json(json.data)
	ctx.settings.changed.connect(__save_settings)
