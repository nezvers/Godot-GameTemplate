extends Node

@export var player_reference:ReferenceNodeResource
@export var game_over_scene_path:String
@export var wait_time:float = 0.5

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
	var next_scene:PackedScene = load(game_over_scene_path)
	assert(next_scene != null)
	var scene_tree:SceneTree = get_tree()
	var err:int = scene_tree.change_scene_to_packed(next_scene)
	assert(err == 0)
