extends Node


@export var graphics_resource:GraphicsResource
@export var fullscreen_button:Button
@export var fullscreen_label:Label
@export var save_button_button:Button

func _ready()->void:
	fullscreen_button.pressed.connect(toggle_fullscreen)
	save_button_button.pressed.connect(save_settings)
	graphics_resource.enable_resize_tracking(get_viewport())
	graphics_resource.window_mode_changed.connect(update_label)
	graphics_resource.load_resource()
	PersistentData.data["graphics"] = graphics_resource

func toggle_fullscreen()->void:
	graphics_resource.toggle_fullscreen()

func update_label()->void:
	if graphics_resource.is_fullscreen():
		fullscreen_label.text = "Fullscreen: ON"
	else:
		fullscreen_label.text = "Fullscreen: OFF"

func save_settings()->void:
	graphics_resource.save_resource()
