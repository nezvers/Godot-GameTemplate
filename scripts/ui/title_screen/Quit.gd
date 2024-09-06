extends Node

@export var button:Button

func _ready()->void:
	button.pressed.connect(pressed)

func pressed()->void:
	get_tree().quit()
