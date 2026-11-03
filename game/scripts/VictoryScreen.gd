## Victory screen: plays the zen victory animation first, then shows the menu.
extends Node

@export var overlay_scene: PackedScene
## Hidden while the animation plays.
@export var menu: Control
@export var room_state_resource: RoomStateResource
@export var score_resource: ScoreResource
## Reaching a boss room's victory exit unlocks New Game+.
@export var campaign_resource: CampaignResource

func _ready() -> void:
	if campaign_resource != null:
		campaign_resource.unlock_ng_plus()
	if overlay_scene == null:
		return
	menu.visible = false
	var _layer: CanvasLayer = CanvasLayer.new()
	add_child(_layer)
	var _anim: Node2D = overlay_scene.instantiate()
	_anim.pointer_input = false
	_anim.set_text_args([
		room_state_resource.cleared_section_count() if room_state_resource != null else 0,
		score_resource.value if score_resource != null else 0,
	])
	var _width: float = get_viewport().get_visible_rect().size.x
	_anim.position.x = roundf((_width - _anim.design_size.x) * 0.5)
	_layer.add_child(_anim)
	await _anim.finished
	_layer.queue_free()
	menu.visible = true
	var _button: Button = menu.find_child("Button") as Button
	if _button != null:
		_button.grab_focus()
