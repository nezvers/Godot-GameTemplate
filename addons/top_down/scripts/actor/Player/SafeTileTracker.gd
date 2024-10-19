class_name SafeTileTracker
extends Node

@export var obstacle_tilemap_reference:ReferenceNodeResource
@export var actor:Node2D

var safe_tile:Vector2i
var tile_map_layer:TileMapLayer

func _ready()->void:
	assert(obstacle_tilemap_reference != null)
	assert(actor != null)
	
	tree_entered.connect(on_tree_enter)
	on_tree_enter()

func on_tree_enter()->void:
	obstacle_tilemap_reference.listen(self, tilemap_layer_changed)


func tilemap_layer_changed()->void:
	if !is_inside_tree():
		return
	if obstacle_tilemap_reference.node == null:
		return
	tile_map_layer = obstacle_tilemap_reference.node
	var _actor_pos:Vector2 = actor.global_position
	safe_tile = tile_map_layer.local_to_map(_actor_pos)

func _physics_process(delta:float)->void:
	var _actor_pos:Vector2 = actor.global_position
	var _tile_pos:Vector2i = tile_map_layer.local_to_map(_actor_pos)
	if _tile_pos == safe_tile:
		return
	
	var _tile_id:int = tile_map_layer.get_cell_source_id(_tile_pos)
	if _tile_id == -1:
		safe_tile = _tile_pos
		return

func move_to_safe_position()->void:
	var _pos:Vector2 = tile_map_layer.map_to_local(safe_tile)
	actor.global_position = _pos
