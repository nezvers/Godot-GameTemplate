## Every enemy leaves its own corpse instead of borrowing another enemy's death,
## the fists show a fist and throw a punch, and the floor/wall/hole tilesets carry
## mossy (10) and bloody (20) overlay looks plus metal (30), sandstone (40) and flesh (50)
## re-skins, all of which the autotiler keeps.
##   Godot --headless --path . res://game/tests/asset_variants_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const ROOM_START:String = "res://game/scenes/room_start.tscn"
const ACTORS:String = TD + "resources/InstanceResources/actors/"
const DEAD:String = TD + "scenes/vfx/dead/"

const TILESETS:Array[String] = [
	TD + "resources/tilesets/tileset_isometric_floors.tres",
	TD + "resources/tilesets/tileset_isometric_walls.tres",
	TD + "resources/tilesets/tileset_isometric_holes.tres",
]
const LOOKS:Array[int] = [10, 20, 30, 40, 50]
## Full re-skins: same footprint as the base, but none of its colours.
const RESKINS:Array[int] = [30, 40, 50]

## actor instance resource -> death scene it has to spawn
const DEATHS:Dictionary = {
	"bloater_instance_resource.tres": "bloater_dead.tscn",
	"acid_slime_instance_resource.tres": "acid_slime_dead.tscn",
	"giant_zombie_instance_resource.tres": "giant_zombie_dead.tscn",
	"broodmother_instance_resource.tres": "broodmother_dead.tscn",
	"plague_mother_instance_resource.tres": "plague_mother_dead.tscn",
}

var failures:int = 0
var checks:int = 0
var _room:Node

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	(load(TD + "resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	_check_fists()
	for _path:String in TILESETS:
		_check_tileset(load(_path))
	_check_autotiler_keeps_look()
	_check_floor_edges()
	_room = (load(ROOM_START) as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)
	var _player:Node2D = (load(TD + "resources/ReferenceNodeResources/player_reference.tres") as ReferenceNodeResource).node
	check(_player != null, "player spawned")
	if _player != null:
		for _actor:String in DEATHS:
			await _check_death(_actor, DEATHS[_actor], _player.global_position + Vector2(0, 40))
	_finish()

func _check_fists()->void:
	var _fists:Node = (load(TD + "scenes/weapons/fists.tscn") as PackedScene).instantiate()
	var _sprite:Sprite2D = _fists.get_node("RotatedNode/Sprite2D")
	check(_fists.get_node("RotatedNode").visible, "fists are drawn in hand")
	check(_sprite.texture != null && _sprite.texture.resource_path.get_file() == "fist_0.png", "fists hold the fist sprite")
	check(_fists.get_node("WeaponTrigger/AnimationTrigger").animation_list == [&"punch"], "fists jab on attack")
	_fists.free()
	var _punch:Node = (load(TD + "scenes/projectiles/fist_slash.tscn") as PackedScene).instantiate()
	var _punch_sprite:Sprite2D = _punch.get_node("RotatedNode/Sprite2D")
	check(_punch_sprite.texture.resource_path.get_file() == "punch_16x16_strip4.png", "fist projectile draws the punch impact")
	_punch.free()

## Each look is a copy of the base source: same tiles, same per-tile data, another texture.
func _check_tileset(tile_set:TileSet)->void:
	var _name:String = tile_set.resource_path.get_file()
	var _base:TileSetAtlasSource = tile_set.get_source(tile_set.get_source_id(0))
	for _look:int in LOOKS:
		check(tile_set.has_source(_look), "%s has look %d" % [_name, _look])
		if !tile_set.has_source(_look):
			continue
		var _source:TileSetAtlasSource = tile_set.get_source(_look)
		check(_source.texture != null && _source.texture != _base.texture, "%s look %d has its own atlas" % [_name, _look])
		check(_source.texture.get_size() == _base.texture.get_size(), "%s look %d atlas matches the base size" % [_name, _look])
		check(_source.get_tiles_count() == _base.get_tiles_count(), "%s look %d has every base tile" % [_name, _look])
		for _i:int in _base.get_tiles_count():
			var _coord:Vector2i = _base.get_tile_id(_i)
			if !_source.has_tile(_coord):
				check(false, "%s look %d misses tile %s" % [_name, _look, _coord])
				continue
			var _a:TileData = _base.get_tile_data(_coord, 0)
			var _b:TileData = _source.get_tile_data(_coord, 0)
			var _same:bool = _a.texture_origin == _b.texture_origin && _a.y_sort_origin == _b.y_sort_origin
			for _layer:int in tile_set.get_custom_data_layers_count():
				_same = _same && _a.get_custom_data_by_layer_id(_layer) == _b.get_custom_data_by_layer_id(_layer)
			check(_same, "%s look %d tile %s keeps the base tile data" % [_name, _look, _coord])
		_check_pixels(_name, _look, _base.texture.get_image(), _source.texture.get_image())

## Every look keeps the base footprint pixel for pixel; a re-skin repaints (nearly) all of it.
func _check_pixels(tileset_name:String, look:int, base:Image, image:Image)->void:
	if base.get_size() != image.get_size():
		return
	var _alpha_ok:bool = true
	var _opaque:int = 0
	var _same:int = 0
	for _y:int in base.get_height():
		for _x:int in base.get_width():
			var _a:Color = base.get_pixel(_x, _y)
			var _b:Color = image.get_pixel(_x, _y)
			_alpha_ok = _alpha_ok && is_equal_approx(_a.a, _b.a)
			if _a.a > 0.0:
				_opaque += 1
				if _a.r8 == _b.r8 && _a.g8 == _b.g8 && _a.b8 == _b.b8:
					_same += 1
	check(_alpha_ok, "%s look %d keeps the base footprint" % [tileset_name, look])
	if look in RESKINS:
		check(_same * 20 < _opaque, "%s look %d repaints the base (%d of %d pixels unchanged)" % [tileset_name, look, _same, _opaque])

## Painting a mossy floor and regenerating walls/holes gives mossy walls and holes;
## Fix Visual leaves a painted look alone.
func _check_autotiler_keeps_look()->void:
	var _floor:TileMapLayer = TileMapLayer.new()
	_floor.tile_set = load(TILESETS[0])
	add_child(_floor)
	# a 6x6 floor island with a 2x2 gap in the middle
	for _x:int in 6:
		for _y:int in 6:
			if !(_x in [2, 3] && _y in [2, 3]):
				_floor.set_cell(Vector2i(_x, _y), 10, Vector2i(0, 3))
	for _kind:int in [TileVisualAutotiler.LayerKind.WALL, TileVisualAutotiler.LayerKind.HOLE]:
		var _layer:TileMapLayer = TileMapLayer.new()
		_layer.tile_set = load(TILESETS[1] if _kind == TileVisualAutotiler.LayerKind.WALL else TILESETS[2])
		add_child(_layer)
		var _tiler:TileVisualAutotiler = TileVisualAutotiler.new()
		_tiler.tilemap_layer = _layer
		_tiler.floor_layer = _floor
		_tiler.layer_kind = _kind
		_tiler.marker_atlas = Vector2i(1, 2) if _kind == TileVisualAutotiler.LayerKind.WALL else Vector2i(0, 0)
		_layer.add_child(_tiler)
		_tiler.generate_from_floor()
		_tiler.autotile()
		var _cells:Array[Vector2i] = _layer.get_used_cells()
		var _label:String = "walls" if _kind == TileVisualAutotiler.LayerKind.WALL else "holes"
		check(!_cells.is_empty(), "autotiler made %s around the mossy floor" % _label)
		check(_cells.all(func (c:Vector2i)->bool: return _layer.get_cell_source_id(c) == 10), "generated %s take the mossy floor look" % _label)
		# repaint one cell bloody: Fix Visual keeps it
		_layer.set_cell(_cells[0], 20, _layer.get_cell_atlas_coords(_cells[0]))
		_tiler.autotile()
		check(_layer.get_cell_source_id(_cells[0]) == 20, "Fix Visual keeps a painted bloody %s cell" % _label)
		_layer.free()
	_floor.free()

## Floor Fix Visual: an edge never points at another floor tile, every side facing a hole
## gets an edge (even on one-tile-wide strips the art can't fully draw), and a cell whose
## only empty neighbour is a diagonal gets the inner corner tile.
func _check_floor_edges()->void:
	var _floor:TileMapLayer = TileMapLayer.new()
	_floor.tile_set = load(TILESETS[0])
	add_child(_floor)
	# rows y=0 and y=2 are one-tile-wide strips around the gap row y=1
	for _x:int in 7:
		for _y:int in 3:
			if !(_y == 1 && _x in range(1, 6)):
				_floor.set_cell(Vector2i(_x, _y), 10, Vector2i(0, 3))
	# a 3x3 block missing its top cell: the centre is an inner corner
	for _x:int in range(10, 13):
		for _y:int in range(0, 3):
			if Vector2i(_x, _y) != Vector2i(10, 0):
				_floor.set_cell(Vector2i(_x, _y), 0, Vector2i(0, 3))
	var _tiler:TileVisualAutotiler = TileVisualAutotiler.new()
	_tiler.tilemap_layer = _floor
	_tiler.floor_layer = _floor
	_tiler.layer_kind = TileVisualAutotiler.LayerKind.FLOOR
	_floor.add_child(_tiler)
	_tiler.autotile()
	var _gap:Array[Vector2i] = []
	for _x:int in range(1, 6):
		_gap.append(Vector2i(_x, 1))
	for _cell:Vector2i in _floor.get_used_cells():
		var _atlas:Vector2i = _floor.get_cell_atlas_coords(_cell)
		var _edges:int = TileVisualAutotiler._FLOOR_EDGES.get(_atlas, 0)
		for _bit:int in TileVisualAutotiler._FLOOR_SIDES:
			var _n:Vector2i = _cell + TileVisualAutotiler._FLOOR_SIDES[_bit]
			if _floor.get_cell_source_id(_n) != -1:
				check(!(_edges & _bit), "floor %s %s has no edge toward floor %s" % [_cell, _atlas, _n])
			elif _n in _gap:
				check(_edges & _bit, "floor %s %s has an edge toward the hole %s" % [_cell, _atlas, _n])
	check(_floor.get_cell_source_id(Vector2i(2, 0)) == 10, "Fix Visual keeps the floor look")
	check(_floor.get_cell_atlas_coords(Vector2i(11, 1)) == Vector2i(2, 2), "inner corner gets the top vertex notch")
	_floor.free()

func _check_death(actor_file:String, dead_file:String, position:Vector2)->void:
	var _actor_resource:InstanceResource = load(ACTORS + actor_file)
	var _actor:Node2D = _actor_resource.instance(func (inst:Node2D)->void: inst.global_position = position)
	await _frames(3)
	(_actor.get_node("ResourceNode").get_resource("health") as HealthResource).insta_kill()
	await _frames(3)
	var _corpses:Array[Node] = _find_scene(get_tree().root, DEAD + dead_file)
	check(!_corpses.is_empty(), "%s leaves %s" % [actor_file, dead_file])
	for _corpse:Node in _corpses:
		_corpse.queue_free()
	await _frames(2)

func _find_scene(node:Node, scene_path:String)->Array[Node]:
	var _found:Array[Node] = []
	if node.scene_file_path == scene_path && node.is_inside_tree():
		_found.append(node)
	for _child:Node in node.get_children():
		_found.append_array(_find_scene(_child, scene_path))
	return _found

func _finish()->void:
	print("asset_variants_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
