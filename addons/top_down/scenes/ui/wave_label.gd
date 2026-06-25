class_name WavePanel
extends Node

@export var label:Label

@export var fight_mode_resource:BoolResource

@export var wave_count_resource:IntResource

## True once every section is cleared (whole room done).
@export var room_cleared_resource:BoolResource

@export var tweened_node:Control

var wave:int = 0

var tween:Tween

## True once a fight has started this room, so the idle->"Cleared" transition
## only shows after real combat (not on a fresh, never-fought room).
var fought:bool = false

func _ready()->void:
	fight_mode_resource.updated.connect(_on_fight_mode_changed)
	wave_count_resource.updated.connect(_on_wave_changed)
	if room_cleared_resource != null:
		room_cleared_resource.updated.connect(_refresh)
	tweened_node.pivot_offset = tweened_node.size * 0.5
	_refresh()

func _on_fight_mode_changed()->void:
	if fight_mode_resource.value:
		fought = true
	_refresh()

func _on_wave_changed()->void:
	_refresh()
	_pulse()

## Decide what the label shows from the three states:
##   room cleared      -> "Room Cleared!"
##   fighting          -> "Wave: N"
##   fought, now idle  -> "Cleared" (a section finished, room not done)
func _refresh()->void:
	# An active fight always wins: never show "Room Cleared!" over live waves,
	# even if room_cleared_resource is briefly stale from the previous room.
	if fight_mode_resource.value:
		label.text = "Wave: %d" % wave_count_resource.value
		label.visible = true
		return
	if room_cleared_resource != null && room_cleared_resource.value:
		label.text = "Room Cleared!"
		label.visible = true
		return
	if fought:
		label.text = "Cleared"
		label.visible = true
		return
	label.visible = false

func _pulse()->void:
	tweened_node.rotation = randf_range(-PI *0.1, PI * 0.1)
	tweened_node.scale = Vector2(1.2, 1.2)
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_property(tweened_node, "rotation", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(tweened_node, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
