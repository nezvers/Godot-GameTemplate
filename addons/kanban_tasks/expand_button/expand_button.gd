@tool
extends Button


signal state_changed(expanded: bool)

@export var expanded: bool = true:
	set(value):
		if value != expanded:
			expanded = value
			__update_icon()
			state_changed.emit(expanded)

var __texture_rect := TextureRect.new()


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	center.add_child(__texture_rect)
	pressed.connect(__on_pressed)
	text = " "
	__update_icon()


func _notification(what) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		__texture_rect.texture = get_theme_icon(&"Collapse", &"EditorIcons")


func __update_icon() -> void:
	__texture_rect.flip_v = expanded


func __on_pressed() -> void:
	expanded = !expanded
