## Handles button state style tweening using AnimatedStyleBoxFlat
class_name ButtonAnimator
extends Node

@export var button:Button
@export var label:Label

var default_shader_parameters: = {
	scale = 1.0,
	rotation = 0.0,
	skew = Vector2.ZERO,
}

## References unique style resource put on all buttons states and manipulated with tweens
var style_box:AnimatedStyleBoxFlat
## Collects each button state's style resource
var style_dictionary:Dictionary = {}
## Holds a Tween for each style property
var tweens_style:Dictionary = {}
## Holds a Tween for each shader property
var tweens_shader:Dictionary = {}

var is_down:bool
var is_hover:bool
var is_focused:bool
var should_focus:bool
var material:ShaderMaterial

func _ready()->void:
	setup_style()
	
	button.button_down.connect(set_is_down.bind(true))
	button.button_up.connect(set_is_down.bind(false))
	button.mouse_entered.connect(set_is_hover.bind(true))
	button.mouse_exited.connect(set_is_hover.bind(false))
	button.focus_entered.connect(set_is_focused.bind(true))
	button.focus_exited.connect(set_is_focused.bind(false))
	button.visibility_changed.connect(visibility_changed)
	
	if button.material != null:
		material = button.material.duplicate()
		button.material = material

## Style resource need to be unique to not change it for other buttons.
## But it needs to be the same resource on all states to morph between styles
func setup_style()->void:
	collect_style("normal")
	collect_style("pressed")
	collect_style("hover")
	collect_style("focus")
	collect_style("disabled")
	
	style_box = style_dictionary["normal"].duplicate()
	label.label_settings = style_box.label_settings.duplicate()
	button.add_theme_stylebox_override("normal", style_box)
	button.add_theme_stylebox_override("pressed", style_box)
	button.add_theme_stylebox_override("hover", style_box)
	button.add_theme_stylebox_override("focus", style_box)
	button.add_theme_stylebox_override("disabled", style_box)

## Add a style to the style_dictionary
func collect_style(state_name:String)->void:
	var current_style:StyleBox = button.get_theme_stylebox(state_name)
	
	assert(current_style != null, "No style assinged to an animated button - " + state_name)
	assert(current_style is AnimatedStyleBoxFlat, "Style is not AnimatedStyleBoxFlat for state - " + state_name)
	
	style_dictionary[state_name] = current_style.duplicate()

func set_is_down(value:bool)->void:
	is_down = value
	if is_down:
		set_style_tween(style_dictionary["pressed"])
	elif is_focused:
		set_style_tween(style_dictionary["focus"])
	elif is_hover:
		set_style_tween(style_dictionary["hover"])
	else:
		set_style_tween(style_dictionary["normal"])

func set_is_hover(value:bool)->void:
	is_hover = value
	if is_focused:
		return
	if is_hover:
		set_style_tween(style_dictionary["hover"])
	else:
		set_style_tween(style_dictionary["normal"])

func set_is_focused(value:bool)->void:
	is_focused = value
	if is_focused:
		set_style_tween(style_dictionary["focus"])
	elif is_hover:
		set_style_tween(style_dictionary["hover"])
	else:
		set_style_tween(style_dictionary["normal"])
	if !button.is_visible_in_tree():
		should_focus = true

func visibility_changed()->void:
	if !button.visible:
		return
	if should_focus:
		button.grab_focus()
		should_focus = false

## Tween all properties of a buttons style into new values
func set_style_tween(animated_style:AnimatedStyleBoxFlat)->void:
	if is_queued_for_deletion() || !is_inside_tree():
		return
	# STYLEBOX
	for property in animated_style.tween_list:
		if !tweens_style.has(property):
			# populate dictionary slots
			tweens_style[property] = null
		
		var _tween:Tween = tweens_style[property]
		if _tween != null:
			_tween.kill()
		_tween = create_tween()
		tweens_style[property] = _tween
		_tween.tween_property(style_box, NodePath(property), animated_style.get(property), animated_style.tween_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# LABEL
	for property in animated_style.label_tween_list:
		if !tweens_style.has(property):
			# populate dictionary slots
			tweens_style[property] = null
		
		var _tween:Tween = tweens_style[property]
		if _tween != null:
			_tween.kill()
		_tween = create_tween()
		tweens_style[property] = _tween
		_tween.tween_property(label.label_settings, NodePath(property), animated_style.label_settings.get(property), animated_style.tween_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## Tween shader parameters as part of button style states
func set_shader_tween(_animated_style:AnimatedStyleBoxFlat, parameter_list:Array[StringName])->void:
	material.set_shader_parameter("size", button.size)
	for parameter in parameter_list:
		if !tweens_shader.has(parameter):
			tweens_shader[parameter] = null
		var _tween:Tween = tweens_shader[parameter]
		if _tween != null:
			_tween.kill()
		_tween = create_tween()
		tweens_shader[parameter] = _tween
		## TODO: actual tweening of shader parameters
		material.set_shader_parameter(parameter, default_shader_parameters[parameter])
