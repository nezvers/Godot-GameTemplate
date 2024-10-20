class_name PlayerSpawner
extends Node2D

## Reference to a player. If player object doesn't exist it will be spawned
@export var player_reference:ReferenceNodeResource
## Scene used to instantiate player's object
@export var player_scene:PackedScene
## Places player under referenced node
@export var parent_reference:ReferenceNodeResource
@export var scene_transition_resource:SceneTransitionResource

func _ready()->void:
	assert(player_reference != null)
	assert(player_scene != null)
	assert(parent_reference != null)
	assert(parent_reference.node != null, "Don't place parent node below, or it will _ready() after this node.")
	
	scene_transition_resource.change_scene.connect(on_scene_transition)
	
	if player_reference.node != null:
		## Allow doors to register themselves.
		on_player_scene_entry.call_deferred()
		return
	
	var _player:Node2D = player_scene.instantiate()
	_player.global_position = global_position
	parent_reference.node.add_child(_player)

func on_player_scene_entry()->void:
	assert(scene_transition_resource.entry_match != null)
	assert(scene_transition_resource.entry_match.is_inside_tree())
	assert(!scene_transition_resource.entry_match.is_queued_for_deletion())
	
	var _player:Node2D = player_reference.node
	_player.global_position = scene_transition_resource.entry_match.global_position
	parent_reference.node.add_child(_player)

func on_scene_transition()->void:
	parent_reference.node.remove_child(player_reference.node)
	get_tree().change_scene_to_file(scene_transition_resource.next_scene_path)
