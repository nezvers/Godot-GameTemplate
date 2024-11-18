class_name BindingButton
extends TextureButton


@export var label:Label
@export var control_texture_kb:ControlTextureResource
@export var control_texture_gp:ControlTextureResource
@export var action_resource:ActionResource
@export var action_name:StringName
## Variable name in action_resource that needs to be manipulated
@export var event_variable:StringName
## Used when event is null. Example - for aiming mause is always used.
@export var default_texture:Texture
enum EventType {KEYBOARD, GAMEPAD}
@export var type:EventType
# TODO: Xbox, PS, Switch gamepad detection 

## saved for comparison if visuals need to be changed
var current_event:InputEvent

func _ready()->void:
	control_texture_kb.initialize()
	control_texture_gp.initialize()
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	_set_event(action_resource.get(event_variable) as InputEvent)
	action_resource.updated.connect(_on_action_resource_update)

func _on_action_resource_update()->void:
	var _current_event:InputEvent = action_resource.get(event_variable)
	if _current_event == current_event:
		return
	_set_event(_current_event)

func _set_event(event:InputEvent)->void:
	current_event = event
	if event == null:
		_set_empty()
		return
	
	var _texture:Texture
	if type == EventType.KEYBOARD:
		_texture = control_texture_kb.get_texture(event)
	else:
		# TODO: Use correct gamepad textures (Xbox, PS, Switch)
		_texture = control_texture_gp.get_texture(event)
	
	if _texture == null:
		_label_fallback(event)
		return
	
	texture_normal = _texture

func _set_empty()->void:
	if default_texture != null:
		texture_normal = default_texture
		label.text = ""
	else:
		texture_normal = null
		label.text = "EMPTY"

## TODO: fallback to label if no texture assigned for input type
func _label_fallback(event:InputEvent)->void:
	texture_normal = null
	print("BindingButton [INFO]: ", event.as_text())
	# TODO: this is bad way to parse information by using the first word
	label.text = event.as_text().split(" ")[0]

func _on_focus_changed(value:bool)->void:
	#if value:
		#modulate = Color.DIM_GRAY
	#else:
		#modulate = Color.WHITE
	queue_redraw()

## TODO: Take in account which gamepad is used for each player
func change_binding(event:InputEvent)->void:
	var _current_event:InputEvent = action_resource.get(event_variable)
	if _current_event != null:
		action_resource.erase_input(action_name, _current_event)
	action_resource.set(event_variable, event)
	if event == null:
		_set_event(event)
		return
	# Will trigger update signal and automatically update visuals
	action_resource.set_input(action_name, event)

func _draw() -> void:
	if !has_focus():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 1.0)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), Color.BLACK, false, 1.0)
