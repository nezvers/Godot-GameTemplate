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
		target_count = 0
		var _collision_count:int = shape_cast.get_collision_count()
		for i:int in _collision_count:
			var _collider:PhysicsBody2D = shape_cast.get_collider(i)
			if _collider is StaticBody2D:
				continue
			target_list[i] = _collider
			target_count += 1
	else:
		target_count = 0
	closest = GameMath.get_closest_node_2d(bot_input.global_position, target_list, target_count)
	
	target_update.emit()
