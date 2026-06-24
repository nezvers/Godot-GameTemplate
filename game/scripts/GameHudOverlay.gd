## Game-owned HUD overlay drawn on top of the template's game_hud.
## Renders the mini-game's "Room cleared" banner. The room id is shown natively
## by the template GameHud's InfoTracker.
extends CanvasLayer

## Centered banner shown when the current room is cleared.
@export var cleared_label: Label

## Shared flag (BoolResource): true when the current room is cleared.
@export var room_cleared_resource: BoolResource

var _tween: Tween

func _ready() -> void:
	assert(cleared_label != null)
	assert(room_cleared_resource != null)

	cleared_label.text = "Room cleared"

	room_cleared_resource.changed_true.connect(_show_cleared)
	room_cleared_resource.changed_false.connect(_hide_cleared)

	cleared_label.visible = room_cleared_resource.value

func _show_cleared() -> void:
	cleared_label.visible = true
	cleared_label.pivot_offset = cleared_label.size * 0.5
	cleared_label.scale = Vector2(1.2, 1.2)
	cleared_label.rotation = randf_range(-PI * 0.1, PI * 0.1)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(cleared_label, "rotation", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.parallel().tween_property(cleared_label, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _hide_cleared() -> void:
	cleared_label.visible = false
