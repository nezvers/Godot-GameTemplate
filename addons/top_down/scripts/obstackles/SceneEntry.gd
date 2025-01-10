class_name SceneEntry
extends Area2D

## Traversing between changing rooms it is used to identify where to put player
@export var tag:String

## Used to connect to a tag on the other side after transitioning scenes
@export var connect_tag:String

## Scene's file path that will be next scene
@export var scene_path:String

## Resource to carry transition information
@export var scene_transition_resource:SceneTransitionResource


func _ready()->void:
	assert(!tag.is_empty())
	assert(!connect_tag.is_empty())
	assert(!scene_path.is_empty())
	
	# NOTE: Player and entries disable_mode is set KEEP_ACTIVE, because pausing removed nodes from physics
	disable_mode = DISABLE_MODE_KEEP_ACTIVE
	
	if scene_transition_resource.entry_tag == tag:
		# This entry was marked as a scene's entry.
		scene_transition_resource.entry_match = self
		# Connect entry signal after player has exited the area
		body_exited.connect(_on_body_exited, CONNECT_ONE_SHOT)
		return
	
	# Because physics could trigger multiple times before executing travel, connect one shot
	body_entered.connect(_on_body_entered, CONNECT_ONE_SHOT)


func _on_body_entered(body:Node2D)->void:
	scene_transition_resource.set_next_scene(scene_path, connect_tag)


func _on_body_exited(body:Node2D)->void:
	# Because physics could trigger multiple times before executing travel, connect one shot
	body_entered.connect(_on_body_entered, CONNECT_ONE_SHOT)
