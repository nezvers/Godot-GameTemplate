class_name ChangeSceneButton
extends Node

@export var button:Button
@export var scene_path:String

func _ready()->void:
	button.pressed.connect(pressed)

func pressed()->void:
	# Avoid triggering multiple times
	# Deffered because this function is called by that signal
	button.pressed.disconnect.call_deferred(pressed)
	
	Transition.change_scene(scene_path)
