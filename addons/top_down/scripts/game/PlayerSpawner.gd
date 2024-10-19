class_name PlayerSpawner
extends Node2D

## Reference to a player. If player object doesn't exist it will be spawned
@export var player_reference:ReferenceNodeResource
## Scene used to instantiate player's object
@export var player_scene:PackedScene
@export var parent_reference:ReferenceNodeResource

func _ready()->void:
	assert(player_reference != null)
	assert(player_scene != null)
	assert(parent_reference != null)
	assert(parent_reference.node != null, "Don't place parent node below, or it will instantiate later.")
	
	if player_reference.node != null:
		return
	
	var _player:Node2D = player_scene.instantiate()
	_player.global_position = global_position
	parent_reference.node.add_child(_player)
