@tool
## Collects tiles for obstacles and puts information into AStarGrid2D for navigation path calculations
class_name TileCollisionGenerator
extends Node

## Tool function to generate colliders in editor
@export var generate_colliders:bool : set = set_generate_colliders

## TileMapLayer for creating obstacle tiles
@export var tilemap_layer:TileMapLayer

@export var static_body:StaticBody2D

@export var tile_shape:Shape2D

## Custom tile data name of PackedVector2Array for collider offsets
@export var data_name:String = "collider_offset"


func set_generate_colliders(value:bool)->void:
	if !is_inside_tree():
		return
	if !Engine.is_editor_hint():
		return
	cleanup()
	setup_colliders()

## Free obstacles from AstarGrid & PhysicsServer
func cleanup() -> void:
	for child:Node in static_body.get_children():
		remove_child(child)
		child.queue_free()


func setup_colliders()->void:
	# Cache custom data names to later check if exist
	var _tile_data_count:int = tilemap_layer.tile_set.get_custom_data_layers_count()
	var _tile_data_names:Array[String]
	_tile_data_names.resize(_tile_data_count)
	for i:int in _tile_data_count:
		_tile_data_names[i] = tilemap_layer.tile_set.get_custom_data_layer_name(i)
	var _has_offset:bool = _tile_data_names.has(data_name)
	
	# TileSet doesn't contain offset data
	if _has_offset == false:
		return
	
	var _tile_pos_list:Array[Vector2i]
	var _tiles:Array[Vector2i] = tilemap_layer.get_used_cells()
	for i:int in _tiles.size():
		var _tile_pos:Vector2i = _tiles[i]
		var _tile_data:TileData = tilemap_layer.get_cell_tile_data(_tile_pos)
		var _offset_list:PackedVector2Array
		if _has_offset:
			_offset_list = _tile_data.get_custom_data(data_name)
		
		# tiles can have multiple collider offsets
		for _offset:Vector2 in _offset_list:
			var _tile_pos_off:Vector2i = _tile_pos + Vector2i(_offset)
			if _tile_pos_list.has(_tile_pos_off):
				continue
			_tile_pos_list.append(_tile_pos_off)
	
	if _tile_pos_list.is_empty():
		return
	
	
	for _tile_pos_off in _tile_pos_list:
		var _poligon_collider:CollisionPolygon2D = CollisionPolygon2D.new()
		_poligon_collider.name = "X" + str(_tile_pos_off.x) + "_Y" + str(_tile_pos_off.y)
		_poligon_collider.polygon = tile_shape.points
		_poligon_collider.position = tilemap_layer.map_to_local(_tile_pos_off)
		static_body.add_child(_poligon_collider)
		_poligon_collider.owner = owner
	

## Collect neighbouring tiles in order and remove from pos_list
func _queue_neighbouring_tiles(pos_list:Array[Vector2i])->Array[Vector2i]:
	# Collect tiles that are next to each other, to make sure polygons are merged
	var _tile_queue:Array[Vector2i] = [pos_list.back()]
	
	var _insert_index:int = 0
	var _size:int = pos_list.size()
	for q:int in _size:
		if _insert_index == _tile_queue.size() && _insert_index > 0:
			# all neighbours are checked
			break
		
		var _tile:Vector2i = _tile_queue[_insert_index]
		pos_list.erase(_tile)
		
		# Use same insertion index so last inserted neighbour has priority over previous
		_insert_index += 1
		
		var _right:Vector2i = _tile + Vector2i.RIGHT
		if pos_list.has(_right) && !_tile_queue.has(_right):
			_tile_queue.insert(_insert_index, _right)
		
		var _down:Vector2i = _tile + Vector2i.DOWN
		if pos_list.has(_down) && !_tile_queue.has(_down):
			_tile_queue.insert(_insert_index, _down)
		
		var _up:Vector2i = _tile + Vector2i.UP
		if pos_list.has(_up) && !_tile_queue.has(_up):
			_tile_queue.insert(_insert_index, _up)
		
		var _left:Vector2i = _tile + Vector2i.LEFT
		if pos_list.has(_left) && !_tile_queue.has(_left):
			_tile_queue.insert(_insert_index, _left)
	
	return _tile_queue

## Sort lowest tile coordinate to be at the end,
func sort_tiles(a:Vector2i, b:Vector2i, width:int)->bool:
	var a_index:int = a.x + a.y * width
	var b_index:int = b.x + b.y * width
	return a_index > b_index
