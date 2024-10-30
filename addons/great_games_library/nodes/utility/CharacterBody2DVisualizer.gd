extends Node2D
@export var character_body:CharacterBody2D
@export var mutiply:float = 1.0 / 60.0
@export var width:float = -1
@export var color:Color

func _process(_delta:float)->void:
	if !visible:
		return
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2.ZERO, character_body.velocity * mutiply, color, width)
