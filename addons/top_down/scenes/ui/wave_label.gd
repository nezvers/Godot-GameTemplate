class_name WavePanel
extends Node

@export var label:Label

@export var fight_mode_resource:BoolResource

@export var wave_count_resource:IntResource

@export var tweened_node:Control

var wave:int = 0

var tween:Tween

func _ready()->void:
	fight_mode_resource.updated.connect(_on_fight_mode_changed)
	wave_count_resource.updated.connect(_on_wave_changed)
	tweened_node.pivot_offset = tweened_node.size * 0.5
	_on_fight_mode_changed()
	_on_wave_changed()

func _on_fight_mode_changed()->void:
	label.visible = fight_mode_resource.value

func _on_wave_changed()->void:
	label.text = "Wave: %d" % wave_count_resource.value
	tweened_node.rotation = randf_range(-PI *0.1, PI * 0.1)
	tweened_node.scale = Vector2(1.2, 1.2)
	if tween != null:
		tween.kill
	tween = create_tween()
	tween.tween_property(tweened_node, "rotation", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(tweened_node, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
