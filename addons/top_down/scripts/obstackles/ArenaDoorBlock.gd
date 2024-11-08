class_name ArenaDoorBlock
extends Node

@export var astargrid_resource:AstarGridResource
@export var fight_bool_resource:BoolResource
@export var position_node:Node2D
@export var animation_player:AnimationPlayer
@export var animation_on:StringName
@export var animation_off:StringName

enum WallState {OFF, ON}
var state:WallState = WallState.OFF

func _ready()->void:
	fight_bool_resource.updated.connect(update)
	update()

func update()->void:
	if astargrid_resource.value == null:
		return
	
	var _new_state:WallState = WallState.ON if fight_bool_resource.value else WallState.OFF
	if _new_state == state:
		return
	state = _new_state
	
	var _tile_pos:Vector2i = astargrid_resource.tilemap_layer.local_to_map(position_node.global_position)
	
	match state:
		WallState.ON:
			animation_player.play(animation_on)
			astargrid_resource.value.set_point_solid(_tile_pos, true)
		WallState.OFF:
			animation_player.play(animation_off)
			astargrid_resource.value.set_point_solid(_tile_pos, false)
