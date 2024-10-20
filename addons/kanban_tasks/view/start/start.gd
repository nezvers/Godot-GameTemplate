@tool
extends Control


const __Singletons := preload("../../plugin_singleton/singletons.gd")
const __EditContext := preload("../edit_context.gd")

signal create_board()
signal open_board(path: String)

@onready var create_board_button: LinkButton = %CreateBoard
@onready var open_board_button: LinkButton = %OpenBoard
@onready var recent_board_holder: VBoxContainer = %RecentBoardHolder
@onready var delete_from_recent_dialog: ConfirmationDialog = %DeleteFromRecent


func _ready() -> void:
	create_board_button.pressed.connect(func(): create_board.emit())
	open_board_button.pressed.connect(func(): open_board.emit(""))
	await get_tree().create_timer(0.0).timeout
	await get_tree().create_timer(0.0).timeout
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)
	ctx.settings.changed.connect(update)
	update()


func update() -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self)

	for child in recent_board_holder.get_children():
		child.queue_free()

	for board in ctx.settings.recent_files:
		var button := LinkButton.new()
		button.underline = LinkButton.UNDERLINE_MODE_NEVER
		button.text = board
		button.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.2))
		button.pressed.connect(__on_open_recent.bind(board))
		recent_board_holder.add_child(button)


func __delete_from_recent(path: String) -> void:
	var ctx: __EditContext = __Singletons.instance_of(__EditContext, self) as __EditContext

	var recent = ctx.settings.recent_files
	var i = recent.find(path)
	if i >= 0:
		recent.remove_at(i)
	ctx.settings.recent_files = recent


func __on_open_recent(path: String) -> void:
	if not FileAccess.file_exists(path):
		if delete_from_recent_dialog.confirmed.is_connected(__delete_from_recent):
			delete_from_recent_dialog.confirmed.disconnect(__delete_from_recent)
		delete_from_recent_dialog.confirmed.connect(__delete_from_recent.bind(path))
		delete_from_recent_dialog.popup_centered()
		return
	open_board.emit(path)
