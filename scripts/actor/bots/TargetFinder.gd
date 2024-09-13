class_name TargetFinder
extends Node

signal target_update

@export var area:Area2D
@export var bot_input:BotInput

var target_list:Array[Node2D]
var closest:Node2D

func _ready()->void:
	bot_input.input_update.connect(on_input_update)

func on_input_update()->void:
	target_list = area.get_overlapping_bodies()
	closest = GameMath.get_closest_node_2d(bot_input.global_position, target_list)
	
	target_update.emit()
