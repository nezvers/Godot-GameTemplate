@tool
extends VBoxContainer


signal entry_action_triggered(entry: __StepEntry, action: __StepEntry.Actions)
signal entry_move_requesed(moved_entry: __StepEntry, target_entry: __StepEntry, move_after_target: bool)

const __StepData := preload("../../data/step.gd")
const __StepEntry := preload("../details/step_entry.gd")

@export var scrollable: bool = true:
	set(value):
		if value != scrollable:
			scrollable = value
			__update_children_settings()

@export var steps_can_be_removed: bool = true:
	set(value):
		if value != steps_can_be_removed:
			steps_can_be_removed = value
			__update_children_settings()

@export var steps_can_be_reordered: bool = true:
	set(value):
		if value != steps_can_be_reordered:
			steps_can_be_reordered = value
			__update_children_settings()

@export var steps_have_context_menu: bool = true:
	set(value):
		if value != steps_have_context_menu:
			steps_have_context_menu = value
			__update_children_settings()

@export var steps_focus_mode := FocusMode.FOCUS_NONE:
	set(value):
		if value != steps_focus_mode:
			steps_focus_mode = value
			__update_children_settings()

var __mouse_entered_step_list: bool = false
var __move_target_entry: __StepEntry = null
var __move_after_target: bool = false

@onready var __scroll_container: ScrollContainer = %ScrollContainer
@onready var __remove_separator: HSeparator = %RemoveSeparator
@onready var __step_list: VBoxContainer = %StepList
@onready var __remove_area: Button = %RemoveArea


func _ready() -> void:
	__remove_area.icon = get_theme_icon(&"Remove", &"EditorIcons")
	__step_list.draw.connect(__on_step_list_draw)
	__step_list.mouse_exited.connect(__on_step_list_mouse_exited)
	__step_list.mouse_entered.connect(__on_step_list_mouse_entered)
	__update_children_settings()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not steps_can_be_removed and not steps_can_be_reordered:
		return false
	if data is __StepEntry:
		if __remove_area.get_global_rect().has_point(get_global_transform() * at_position):
			return true
		__update_move_target(at_position)
		return (__move_target_entry != null)
	return false


func _get_drag_data(at_position: Vector2) -> Variant:
	if not steps_can_be_removed and not steps_can_be_reordered:
		return null
	for entry in get_step_entries():
		if entry.get_global_rect().has_point(get_global_transform() * at_position):
			var preview := Label.new()
			preview.text = entry.step_data.details
			set_drag_preview(preview)
			return entry
	return null


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if __move_target_entry != null:
		entry_move_requesed.emit(data, __move_target_entry, __move_after_target)
		__move_target_entry = null
	if data is __StepEntry:
		if __remove_area.get_global_rect().has_point(get_global_transform() * at_position):
			data.__action(__StepEntry.Actions.DELETE)


func add_step(step: __StepData) -> void:
	var entry = __StepEntry.new()
	entry.step_data = step
	entry.show_behind_parent = true
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	__step_list.add_child(entry)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.action_triggered.connect(__on_entry_action_triggered)
	entry.context_menu_enabled = steps_have_context_menu
	entry.focus_mode = steps_focus_mode


func clear_steps() -> void:
	for step in get_step_entries():
		__step_list.remove_child(step)
		step.queue_free()


func get_step_entries() -> Array[__StepEntry]:
	var step_entries: Array[__StepEntry] = []
	if is_instance_valid(__step_list):
		for child in __step_list.get_children():
			if child is __StepEntry:
				step_entries.append(child)
	return step_entries


func __update_children_settings() -> void:
	if is_instance_valid(__scroll_container):
		__scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if scrollable else ScrollContainer.SCROLL_MODE_DISABLED
	if is_instance_valid(__remove_separator):
		__remove_separator.visible = steps_can_be_removed
	if is_instance_valid(__remove_area):
		__remove_area.visible = steps_can_be_removed
	for entry in get_step_entries():
		entry.context_menu_enabled = steps_have_context_menu
		entry.focus_mode = steps_focus_mode


func __update_move_target(at_position: Vector2) -> void:
	var at_global_position := get_global_transform() * at_position
	# This __mouse_entered_step_list is needed here, as this seemed to be the only reliable solution, as:
	# 1) something is NOK with transforming at_position to global and compare with step_list.global_rect
	# 2) cannot decide what is the visible rect of the step_list
	# 3) _can_drop_data was called even after mouse is outside the list (to the bottom direction)
	if __mouse_entered_step_list:
		var closes_entry: __StepEntry = null
		var smallest_distance: float
		var position_is_after_closes_entry: bool
		for e in get_step_entries():
			var entry_global_rect = e.get_global_rect()
			var distance := abs(at_global_position.y - entry_global_rect.position.y)
			if closes_entry == null or distance < smallest_distance:
				closes_entry = e
				smallest_distance = distance
				position_is_after_closes_entry = false
			distance = abs(at_global_position.y - entry_global_rect.end.y)
			if closes_entry == null or distance < smallest_distance:
				closes_entry = e
				smallest_distance = distance
				position_is_after_closes_entry = true
		__move_target_entry = closes_entry
		__move_after_target = position_is_after_closes_entry
	else:
		__move_target_entry = null
	__step_list.queue_redraw()


func __on_step_list_mouse_entered() -> void:
	__mouse_entered_step_list = true


func __on_step_list_mouse_exited() -> void:
	__mouse_entered_step_list = false
	__update_move_target(get_local_mouse_position())


func __on_step_list_draw() -> void:
	if __move_target_entry != null:
		var target_rect := __step_list.get_global_transform().inverse() * __move_target_entry.get_global_rect()
		var separation = __step_list.get_theme_constant(&"separation")
		var preview_rect := Rect2(
			Vector2(0, target_rect.end.y if __move_after_target else target_rect.position.y - separation),
			Vector2(target_rect.size.x, separation)
		)
		if preview_rect.position.y < 0:
			preview_rect.position.y = 0
		if preview_rect.end.y > __step_list.size.y:
			preview_rect.position.y -= (preview_rect.end.y - __step_list.size.y)
		__step_list.draw_rect(preview_rect, get_theme_color(&"step_move_review_color"))


func __on_entry_action_triggered(entry, action) -> void:
	entry_action_triggered.emit(entry, action)
