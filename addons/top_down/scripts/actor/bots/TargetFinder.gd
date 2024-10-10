class_name TargetFinder
extends Node

signal target_update

@export var shape_cast:ShapeCast2D
@export var bot_input:BotInput

## TODO: So far used only against a one player
const MAX_TARGET:int = 10
var target_count:int
var target_list:Array[Node2D]
var closest:Node2D

func _ready()->void:
	target_list.resize(MAX_TARGET)
	bot_input.input_update.connect(on_input_update)

func on_input_update()->void:
	shape_cast.force_shapecast_update()
	if shape_cast.is_colliding():
		target_count = shape_cast.get_collision_count()
		for i:int in target_count:
			target_list[i] = shape_cast.get_collider(i)
	else:
		target_count = 0
	closest = GameMath.get_closest_node_2d(bot_input.global_position, target_list, target_count)
	
	target_update.emit()
