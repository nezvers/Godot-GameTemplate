extends Node

@export var player_reference:ReferenceNodeResource
@export var game_over_scene_path:String
@export var wait_time:float = 0.5

## Optional zen animation (res://zen/) played over the room before the game over
## screen; its text args are [wave, score]. It holds at its pause marker until a
## click / ui_accept, or overlay_hold_time seconds.
@export var overlay_scene:PackedScene
@export var overlay_hold_time:float = 4.0
@export var wave_number_resource:IntResource
@export var score_resource:ScoreResource

func _ready()->void:
	assert(player_reference != null)
	assert( !game_over_scene_path.is_empty() )
	player_reference.listen(self, on_reference_changed)

func on_reference_changed()->void:
	if player_reference.node == null:
		return
	var _resource_node:ResourceNode = player_reference.node.get_node("ResourceNode")
	assert(_resource_node != null)
	var _health_resource:HealthResource = _resource_node.get_resource("health")
	assert(_health_resource != null)
	_health_resource.dead.connect(on_player_dead)

func on_player_dead()->void:
	var _tween:Tween = create_tween()
	_tween.tween_callback(on_delay).set_delay(wait_time)

func on_delay()->void:
	if overlay_scene != null:
		await _play_overlay()
	var next_scene:PackedScene = load(game_over_scene_path)
	assert(next_scene != null)
	var scene_tree:SceneTree = get_tree()
	var err:int = scene_tree.change_scene_to_packed(next_scene)
	assert(err == 0)

func _play_overlay()->void:
	var _layer:CanvasLayer = CanvasLayer.new()
	## Below Transition (layer 5); ALWAYS so a pausing room can't freeze it.
	_layer.layer = 4
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var _anim:Node2D = overlay_scene.instantiate()
	_anim.pointer_input = false
	_anim.set_text_args([
		wave_number_resource.value if wave_number_resource != null else 0,
		score_resource.value if score_resource != null else 0,
	])
	var _width:float = get_viewport().get_visible_rect().size.x
	_anim.position.x = roundf((_width - _anim.design_size.x) * 0.5)
	_anim.paused.connect(func(_index:int)->void:
		_anim.create_tween().tween_callback(_anim.resume).set_delay(overlay_hold_time))
	_layer.add_child(_anim)
	await _anim.finished
