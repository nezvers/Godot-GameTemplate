@tool
extends PopupMenu


const __BoardData := preload("../../data/board.gd")

var board_data: __BoardData

signal uuid_selected(uuid)


func _init() -> void:
	about_to_popup.connect(__update_items_from_board)
	id_pressed.connect(__on_id_pressed)


func popup_at_local_position(source: CanvasItem, local_position: Vector2) -> void:
	popup_at_global_position(source, source.get_global_transform() * local_position)


func popup_at_global_position(source: CanvasItem, global_position: Vector2) -> void:
	position = global_position
	if not source.get_window().gui_embed_subwindows:
		position += source.get_window().position
	popup()


func popup_at_mouse_position(source: CanvasItem) -> void:
	popup_at_global_position(source, source.get_global_mouse_position())


func __update_items_from_board() -> void:
	clear()
	size = Vector2i.ZERO
	for uuid in board_data.get_categories():
		var i = Image.create(16, 16, false, Image.FORMAT_RGB8)
		i.fill(board_data.get_category(uuid).color)
		var t = ImageTexture.create_from_image(i)
		add_icon_item(t, board_data.get_category(uuid).title)
		set_item_metadata(-1, uuid)


func __on_id_pressed(id) -> void:
	uuid_selected.emit(get_item_metadata(id))
