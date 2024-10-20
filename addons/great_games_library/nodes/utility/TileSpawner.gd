class_name TileSpawner
extends Node

@export var tilemap_layer:TileMapLayer
@export var parent_reference:ReferenceNodeResource
@export var data_layer_name:String

var tile_data_names:Array[String]
var tiles:Array[Vector2i]
var has_data:bool

func _ready()->void:
	# Cache custom data names to later check if exist
	var _tile_data_count:int = tilemap_layer.tile_set.get_custom_data_layers_count()
	tile_data_names.resize(_tile_data_count)
	for i:int in _tile_data_count:
		tile_data_names[i] = tilemap_layer.tile_set.get_custom_data_layer_name(i)
	has_data = tile_data_names.has(data_layer_name)
	if !has_data:
		return
	
	parent_reference.listen(self, _on_parent_updated)

func _on_parent_updated()->void:
	if parent_reference.node == null:
		return
	if !has_data:
		return
	
	# keep scene files in memory
	var _scene_cache:Dictionary
	tiles = tilemap_layer.get_used_cells()
	for i:int in tiles.size():
		var _tile_pos:Vector2i = tiles[i]
		var _tile_data:TileData = tilemap_layer.get_cell_tile_data(_tile_pos)
		var _file_path:String = _tile_data.get_custom_data(data_layer_name)
		## TODO: use Array of paths
		if _file_path.is_empty():
			continue
		
		# scenes in _scene_cache are already loaded in memory
		var _scene:PackedScene = load(_file_path)
		_scene_cache[_file_path] = _scene
		
		var _pos:Vector2 = tilemap_layer.map_to_local(_tile_pos)
		var _instance:Node2D = _scene.instantiate()
		_instance.global_position = _pos
		parent_reference.node.add_child(_instance)
