extends Node

@export var score_resource:ScoreResource
@export var score_label:Label
@export var try_again_button:Button

func _ready()->void:
	try_again_button.pressed.connect(on_try_again_pressed)
	score_label.text = "Score: " + str(score_resource.point_count)

func on_try_again_pressed()->void:
	score_resource.reset_resource()
