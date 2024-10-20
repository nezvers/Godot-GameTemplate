@tool
extends VBoxContainer


const __BoardData := preload("../../../data/board.gd")
const __CategoryEntry := preload("../../settings/categories/category_entry.gd")
const __CategoryData := preload("../../../data/category.gd")
const __EditLabel := preload("../../../edit_label/edit_label.gd")

var board_data: __BoardData

var randomizer := RandomNumberGenerator.new()

@onready var category_holder: VBoxContainer = %CategoryHolder
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var add_category_button: Button = %Add


func _ready() -> void:
	notification(NOTIFICATION_THEME_CHANGED)
	randomizer.randomize()
	add_category_button.pressed.connect(__add_category)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			if is_instance_valid(add_category_button):
				add_category_button.icon = get_theme_icon(&"Add", &"EditorIcons")


func update() -> void:
	for category in category_holder.get_children():
		category.queue_free()

	for uuid in board_data.get_categories():
		var entry := __CategoryEntry.new()
		entry.board_data = board_data
		entry.data_uuid = uuid

		category_holder.add_child(entry)


func __add_category() -> void:
	var color = Color.from_hsv(randomizer.randf(), randomizer.randf_range(0.8, 1.0), randomizer.randf_range(0.7, 1.0))
	var data = __CategoryData.new("New category", color)
	var uuid = board_data.add_category(data)
	update()
	for i in category_holder.get_children():
		if i.data_uuid == uuid:
			await get_tree().create_timer(0.0).timeout
			i.grab_focus()
			i.show_edit(__EditLabel.INTENTION.REPLACE)
