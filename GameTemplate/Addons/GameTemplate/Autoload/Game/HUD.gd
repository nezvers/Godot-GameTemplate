extends Node

onready var hp: = $CanvasLayer/GUI/MarginContainer/VBoxContainer/Top/HP
onready var score: = $CanvasLayer/GUI/MarginContainer/VBoxContainer/Top/Score
onready var gui: = $CanvasLayer/GUI

var visible: = false setget set_visible

func _ready()->void:
	gui.visible = visible

func set_visible(value: bool)->void:
	visible = value
	gui.visible = value
