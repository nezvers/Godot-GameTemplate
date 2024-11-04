class_name DamagePoints
extends Node2D

@export var label:Label
@export var tween_time:float = 1.0
@export var distance:float = 16.0
@export var pool_node:PoolNode


func set_displayed_points(points:int, is_critical:bool)->void:
	label.text = str(points)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER,Control.PRESET_MODE_MINSIZE)

func _ready()->void:
	var _angle:float = randf_range(0.6, 0.9) * TAU
	var _offset:Vector2 = Vector2.RIGHT.rotated(_angle) * distance
	var tween:Tween = create_tween()
	tween.tween_method(tween_move.bind(global_position, global_position + _offset), 0.0, 1.0, tween_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(pool_node.pool_return)

func tween_move(t:float, from:Vector2, to:Vector2)->void:
	global_position = from.lerp(to, t)
