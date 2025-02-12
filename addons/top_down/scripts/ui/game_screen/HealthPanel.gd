class_name HealthPanel
extends Node

@export var health_resource:HealthResource

@export var label:Label

@export var progress_shader:ShaderMaterial

@export var tween_time:float = 0.5

var tween_front:Tween
var tween_midle:Tween

var value_front:float
var value_middle:float

func _ready()->void:
	health_resource.reset_update.connect(_on_reset)
	health_resource.max_hp_changed.connect(_on_reset)
	health_resource.hp_changed.connect(_update)
	_on_reset()

func _on_reset()->void:
	label.text = "%d/%d" % [health_resource.hp, health_resource.max_hp]
	if tween_front != null:
		tween_front.kill()
	if tween_midle != null:
		tween_midle.kill()
	value_front = health_resource.hp / health_resource.max_hp
	value_middle = value_front
	progress_shader.set_shader_parameter("progress_foreground", value_front)
	progress_shader.set_shader_parameter("progress_middle", value_middle)

func _update()->void:
	label.text = "%d/%d" % [health_resource.hp, health_resource.max_hp]
	if tween_front != null:
		tween_front.kill()
	if tween_midle != null:
		tween_midle.kill()
	tween_front = create_tween()
	tween_midle = create_tween()
	
	var _new_value:float = health_resource.hp / health_resource.max_hp
	tween_front.tween_method(_tween_front, value_front, _new_value, tween_time * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_midle.tween_method(_tween_middle, value_middle, _new_value, tween_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

func _tween_front(value:float)->void:
	value_front = value
	progress_shader.set_shader_parameter("progress_foreground", value_front)

func _tween_middle(value:float)->void:
	value_middle = value
	progress_shader.set_shader_parameter("progress_middle", value_middle)
