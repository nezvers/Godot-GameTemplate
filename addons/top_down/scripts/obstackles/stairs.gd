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
	
	if scene_transition_resource.entry_tag == tag:
		# This entry is marked as a scene's entry.
		scene_transition_resource.entry_match = self
		# Connect entry signal after player has exited the area
		body_exited.connect(on_body_exited, CONNECT_ONE_SHOT)
		return
	
	body_entered.connect(on_body_entered)

func on_body_entered(body:Node2D)->void:
	scene_transition_resource.set_next_scene.call_deferred(scene_path, connect_tag)

func on_body_exited(body:Node2D)->void:
	# TODO: BUG - Pausing causes for area think bodies has left
	body_entered.connect(on_body_entered)
