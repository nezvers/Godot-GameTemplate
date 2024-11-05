class_name PlayerSpawner
extends Node2D

## Reference to a player. If player object doesn't exist it will be spawned
@export var player_reference:ReferenceNodeResource
@export var player_instance_resource:InstanceResource
@export var scene_transition_resource:SceneTransitionResource

func _ready()->void:
	assert(player_reference != null)
	assert(player_instance_resource != null)
	
	scene_transition_resource.change_scene.connect(on_scene_transition)
	
	if player_reference.node != null:
		## Allow doors to register themselves.
		on_player_scene_entry.call_deferred()
		return
	
	if player_instance_resource.scene != null:
		_player_loaded()
		return
	
	player_instance_resource.scene_changed.connect(_player_loaded, CONNECT_ONE_SHOT)
	player_instance_resource.preload_scene()

func _player_loaded()->void:
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = global_position
	var _player:Node2D = player_instance_resource.instance(_config_callback)

func on_player_scene_entry()->void:
	assert(scene_transition_resource.entry_match != null)
	assert(scene_transition_resource.entry_match.is_inside_tree())
	assert(!scene_transition_resource.entry_match.is_queued_for_deletion())
	
	var _player:Node2D = player_reference.node
	_player.global_position = scene_transition_resource.entry_match.global_position
	player_instance_resource.parent_reference_resource.node.add_child(_player)

func on_scene_transition()->void:
	player_instance_resource.parent_reference_resource.node.remove_child(player_reference.node)
	
	Transition.change_scene(scene_transition_resource.next_scene_path)
