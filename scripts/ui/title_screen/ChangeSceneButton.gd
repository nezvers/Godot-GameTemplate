#class_name ChangeSceneButton
extends Node

@export var button:Button
@export var scene_path:String

func _ready()->void:
	button.pressed.connect(pressed)

func pressed()->void:
	var next_scene:PackedScene = load(scene_path)
	var scene_tree:SceneTree = get_tree()
	scene_tree.change_scene_to_packed(next_scene)
