@tool
## Spawns scene instances in the editor for tiles carrying a scene path in custom data.
## Editor-time twin of TileSpawner (which spawns at runtime). Generation is additive:
## only marker tiles without an existing generated instance are spawned, so per-instance
## settings on already-generated BlockWalls survive a regenerate.
class_name BlockWallGenerator
extends Node

## Spawn the BlockWall (scene) instances from marker tiles carrying a scene path, saving
## them into this scene. Only marker tiles that don't already have a generated instance
## are spawned — existing BlockWalls are left untouched.
@export var generate_block_wall:bool : set = set_generate

## TileMapLayer holding the placeholder marker tiles.
@export var tilemap_layer:TileMapLayer

## Node the generated instances are parented to (usually the tilemap_layer).
@export var container:Node2D

## Name of the custom tile data layer holding the String scene path to spawn.
@export var data_name:String = "scene_path"

## Erase the placeholder cell after spawning so its art doesn't overlap the spawned scene.
@export var erase_placeholder:bool = true

## Extra offset added to each spawned instance to align it with the tiling grid. The marker
## tile and the iso wall tiles differ in size, so a half-tile correction (+/- tile_w/2,
## tile_h/2) is usually needed; tune here if the spawned scene looks off.
@export var spawn_offset:Vector2 = Vector2(16, 8)


func set_generate(value:bool)->void:
	if !is_inside_tree():
		return
	if !Engine.is_editor_hint():
		return
	setup_scenes()


func setup_scenes()->void:
	# TileSet must expose the scene_path custom data layer
	var _tile_data_count:int = tilemap_layer.tile_set.get_custom_data_layers_count()
	var _tile_data_names:Array[String]
	_tile_data_names.resize(_tile_data_count)
	for i:int in _tile_data_count:
		_tile_data_names[i] = tilemap_layer.tile_set.get_custom_data_layer_name(i)
	if !_tile_data_names.has(data_name):
		return

	# Cells that already have a generated instance — don't recreate them
	var _existing:Dictionary = {}
	for child:Node in container.get_children():
		if child.get_meta("generated_by_scene_tile", false) == true and child.has_meta("source_cell"):
			_existing[child.get_meta("source_cell")] = true

	# Keep loaded scenes in memory across cells
	var _scene_cache:Dictionary
	var _tiles:Array[Vector2i] = tilemap_layer.get_used_cells()
	for _tile_pos:Vector2i in _tiles:
		var _tile_data:TileData = tilemap_layer.get_cell_tile_data(_tile_pos)
		var _file_path:String = _tile_data.get_custom_data(data_name)
		if _file_path.is_empty():
			continue
		# Skip cells already converted to a BlockWall — preserves per-instance settings
		if _existing.has(_tile_pos):
			continue

		var _scene:PackedScene = _scene_cache.get(_file_path, null)
		if _scene == null:
			_scene = load(_file_path)
			_scene_cache[_file_path] = _scene

		var _instance:Node2D = _scene.instantiate()
		_instance.position = tilemap_layer.map_to_local(_tile_pos) + spawn_offset
		_instance.set_meta("generated_by_scene_tile", true)
		# Record source cell so a later regenerate can skip this already-generated cell
		_instance.set_meta("source_cell", _tile_pos)
		# Name as <SceneBase><N>, N incrementing from the highest existing in container.
		# Computed before add_child so the new node doesn't count itself.
		var _base:String = _scene.get_state().get_node_name(0)
		_instance.name = _base + str(_next_name_index(_base))
		container.add_child(_instance)
		# owner = scene root so the instance is saved into the scene file
		_instance.owner = owner

		if erase_placeholder:
			tilemap_layer.erase_cell(_tile_pos)


## Lowest integer N (>= 1) such that "<base><N>" is not already used by a sibling
func _next_name_index(base:String)->int:
	var _used:Dictionary
	for child:Node in container.get_children():
		var _name:String = child.name
		if !_name.begins_with(base):
			continue
		var _suffix:String = _name.substr(base.length())
		# bare base name (no number) counts as index 1
		if _suffix.is_empty():
			_used[1] = true
		elif _suffix.is_valid_int():
			_used[_suffix.to_int()] = true
	var _n:int = 1
	while _used.has(_n):
		_n += 1
	return _n
