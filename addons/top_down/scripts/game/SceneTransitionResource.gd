## Collected information to move between scenes
class_name SceneTransitionResource
extends SaveableResource

signal change_scene

## reference to the player that will be moved to next scene
@export var player_reference:ReferenceNodeResource

## File path to next scene
@export var next_scene_path:String

## Tag for entry to place the player
@export var entry_tag:String

## When entries execute _ready(), matching one should assign itself to the variable
var entry_match:Node2D

func set_next_scene(scene_path:String, entry:String)->void:
	assert(player_reference != null)
	assert(player_reference.node != null)
	assert(!scene_path.is_empty())
	assert(!entry.is_empty())
	
	next_scene_path = scene_path
	entry_tag = entry
	change_scene.emit()
