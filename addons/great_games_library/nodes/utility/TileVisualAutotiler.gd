@tool
## Floor-aware visual autotiler. Paint wall/hole markers anywhere on tilemap_layer, then
## press "Fix Visual Tiles": each painted cell is rewritten to the correct atlas tile based
## on its same-layer neighbors AND the adjacent FloorLayer cells.
##
## Why custom instead of Godot terrain: built-in terrain matching is single-layer and picks
## one tile per neighbor-fingerprint. Walls/holes here need cross-layer info (which side the
## floor is on) and have two variants that share a same-layer fingerprint, so terrain cannot
## express the rule. See addons/top_down/design_document/tiling.md.
class_name TileVisualAutotiler
extends Node

enum LayerKind { WALL, HOLE }

## Tool function: recompute every painted cell's atlas tile from neighbors + floor.
@export var fix_visual:bool : set = set_fix_visual

@export_group("Generate from floor")
## Add wall/hole marker tiles where the floor island boundary needs them, WITHOUT touching
## existing cells, then run Fix Visual. WALL: rings every floor island's outer edge. HOLE:
## fills floor cells that border an interior gap region.
@export var add_missing:bool : set = set_add_missing
## Like add_missing but first clears this layer, rebuilding the whole boundary from scratch.
@export var regenerate:bool : set = set_regenerate

@export_group("Clear")
## Step 1: tick to arm. Step 2: tick Clear to reset all painted cells to the marker tile.
@export var confirm_clear:bool = false
## Tool function: reset painted cells to marker_atlas. Requires confirm_clear first.
@export var clear:bool : set = set_clear

@export_group("")
## The wall/hole layer being painted and rewritten.
@export var tilemap_layer:TileMapLayer
## FloorLayer read to decide which side the floor is on (the cross-layer relationship).
@export var floor_layer:TileMapLayer
## Which atlas table to use: walls and holes have different layouts.
@export var layer_kind:LayerKind = LayerKind.WALL
## Atlas coord used when you paint a plain marker, and the reset target for Clear.
@export var marker_atlas:Vector2i = Vector2i(0, 2)
## Safety: while false, WALL cells are left untouched by Fix Visual. The table is now
## verified 97/97 against room_0_test, so this defaults true; flip off only to paint a new
## wall sample without the autotiler overwriting it. Holes are unaffected by this flag.
@export var wall_table_ready:bool = true

# Side-neighbor map-coord deltas, named by the screen direction they point to in this
# isometric layout (tile_shape=1, tile_layout=5, tile_offset_axis=1):
#   +x -> top-right (TR), -x -> bottom-left (BL), +y -> bottom-right (BR), -y -> top-left (TL)
const SIDE_TR:int = 1   # +x
const SIDE_BR:int = 2   # +y
const SIDE_BL:int = 4   # -x
const SIDE_TL:int = 8   # -y

const _DELTAS := {
	SIDE_TR: Vector2i(1, 0),
	SIDE_BR: Vector2i(0, 1),
	SIDE_BL: Vector2i(-1, 0),
	SIDE_TL: Vector2i(0, -1),
}

# --- ATLAS TABLES ----------------------------------------------------------------------
# HOLE rule, derived & verified 28/28 vs room_0_test. The two back sides (BL, TL) decide
# the edge class; the top-left back-diagonal (-1,-1) selects a "continuing" variant used
# where the hole wraps diagonally behind. See _pick_hole().
#   neither BL nor TL          -> 0:0   (front corner / cap)
#   BL only                    -> 0:1 , or 1:1 when TL-diagonal is also hole
#   TL only                    -> 2:0 , or 2:1 when TL-diagonal is also hole
#   both BL and TL             -> 0:2 , or 1:0 for a thin strip (both back-diagonals empty)
const HOLE_NONE := Vector2i(0, 0)
const HOLE_BL := Vector2i(0, 1)
const HOLE_BL_CONT := Vector2i(1, 1)
const HOLE_TL := Vector2i(2, 0)
const HOLE_TL_CONT := Vector2i(2, 1)
const HOLE_INTERIOR := Vector2i(0, 2)
const HOLE_INTERIOR_STRIP := Vector2i(1, 0)

# WALL rule: the tile is a pure function of the surrounding FLOOR topology (a wall wraps a
# floor cell), verified 200/200 against the hand-made room_0_test layout. See _pick_wall().
# ---------------------------------------------------------------------------------------


func set_fix_visual(_value:bool)->void:
	if !is_inside_tree() or !Engine.is_editor_hint():
		return
	if tilemap_layer == null or floor_layer == null:
		push_warning("TileVisualAutotiler: assign tilemap_layer and floor_layer.")
		return
	autotile()


func set_clear(_value:bool)->void:
	if !is_inside_tree() or !Engine.is_editor_hint():
		return
	if !confirm_clear:
		push_warning("TileVisualAutotiler: tick 'Confirm Clear' before clearing.")
		return
	confirm_clear = false
	notify_property_list_changed()
	reset_to_marker()


func set_add_missing(_value:bool)->void:
	if !is_inside_tree() or !Engine.is_editor_hint():
		return
	if tilemap_layer == null or floor_layer == null:
		push_warning("TileVisualAutotiler: assign tilemap_layer and floor_layer.")
		return
	generate_from_floor()
	autotile()


func set_regenerate(_value:bool)->void:
	if !is_inside_tree() or !Engine.is_editor_hint():
		return
	if tilemap_layer == null or floor_layer == null:
		push_warning("TileVisualAutotiler: assign tilemap_layer and floor_layer.")
		return
	tilemap_layer.clear()
	generate_from_floor()
	autotile()


## Source id used when placing new marker cells (first source on the layer's tileset).
func _marker_source()->int:
	var _ts:TileSet = tilemap_layer.tile_set
	if _ts == null or _ts.get_source_count() == 0:
		return -1
	return _ts.get_source_id(0)


## Place marker tiles along the floor boundary. Existing cells are never overwritten.
## WALL: rings every floor island's outer edge. Placement (measured from room_0_test):
## a floor edge open toward TL or BL puts the wall in the empty neighbour cell (outside);
## open toward TR or BR puts the wall on the floor cell itself (overlap).
## HOLE: marks floor cells that border an interior empty region (a gap enclosed by floor).
func generate_from_floor()->void:
	var _src:int = _marker_source()
	if _src == -1:
		push_warning("TileVisualAutotiler: layer tileset has no source to place markers.")
		return
	var _floor_cells:Array[Vector2i] = floor_layer.get_used_cells()
	var _floor_set:Dictionary = {}
	for c:Vector2i in _floor_cells:
		_floor_set[c] = true

	# Classify every floor-adjacent empty cell as an enclosed gap (-> hole) or exterior
	# (-> wall). Gaps are empty regions fully surrounded by floor.
	var _gap_set:Dictionary = _collect_gaps(_floor_cells, _floor_set)

	if layer_kind == LayerKind.WALL:
		# Ring only the outer edges that face exterior (never into a gap).
		for f:Vector2i in _floor_cells:
			for bit:int in _DELTAS:
				var _np:Vector2i = f + _DELTAS[bit]
				if _floor_set.has(_np) or _gap_set.has(_np):
					continue
				# TL/BL edge -> wall in the empty cell; TR/BR edge -> overlap the floor cell.
				var _target:Vector2i = _np if (bit == SIDE_TL or bit == SIDE_BL) else f
				if tilemap_layer.get_cell_source_id(_target) == -1:
					tilemap_layer.set_cell(_target, _src, marker_atlas)
		# Corner bridge: where a floor's TL and BL neighbours both became walls, fill the
		# up-left diagonal exterior cell so the top corner has no diagonal gap.
		for f:Vector2i in _floor_cells:
			var _tl:Vector2i = f + _DELTAS[SIDE_TL]
			var _bl:Vector2i = f + _DELTAS[SIDE_BL]
			if tilemap_layer.get_cell_source_id(_tl) == -1:
				continue
			if tilemap_layer.get_cell_source_id(_bl) == -1:
				continue
			var _diag:Vector2i = f + Vector2i(-1, -1)
			if _floor_set.has(_diag) or _gap_set.has(_diag):
				continue
			if tilemap_layer.get_cell_source_id(_diag) == -1:
				tilemap_layer.set_cell(_diag, _src, marker_atlas)
		# Interior corner: an interior floor cell whose TR and BR neighbours both became
		# walls (the overlap edges) closes a corner — but only when its BL and TL back
		# sides are symmetric (both floor or both empty). When exactly one of BL/TL is
		# floor the cell sits on the perimeter and must stay empty.
		for f:Vector2i in _floor_cells:
			if tilemap_layer.get_cell_source_id(f) != -1:
				continue
			var _tr:Vector2i = f + _DELTAS[SIDE_TR]
			var _br:Vector2i = f + _DELTAS[SIDE_BR]
			if tilemap_layer.get_cell_source_id(_tr) == -1 or tilemap_layer.get_cell_source_id(_br) == -1:
				continue
			if _floor_set.has(f + _DELTAS[SIDE_BL]) != _floor_set.has(f + _DELTAS[SIDE_TL]):
				continue
			tilemap_layer.set_cell(f, _src, marker_atlas)
	else:
		# HOLE: fill the enclosed gap cells themselves (the empty space inside the floor).
		for gap:Vector2i in _gap_set:
			if tilemap_layer.get_cell_source_id(gap) == -1:
				tilemap_layer.set_cell(gap, _src, marker_atlas)


## Flood-fill every empty cell reachable from the floor's adjacent empties; a connected empty
## region that never escapes far from the floor is an enclosed gap. Returns the set of all
## gap cells. Regions that reach beyond the bound are exterior and excluded.
func _collect_gaps(floor_cells:Array[Vector2i], floor_set:Dictionary)->Dictionary:
	const LIMIT:int = 256
	var _gaps:Dictionary = {}
	var _checked:Dictionary = {}
	for f:Vector2i in floor_cells:
		for bit:int in _DELTAS:
			var _seed:Vector2i = f + _DELTAS[bit]
			if floor_set.has(_seed) or _checked.has(_seed):
				continue
			# Flood this empty region.
			var _region:Dictionary = {_seed: true}
			var _stack:Array[Vector2i] = [_seed]
			var _escaped:bool = false
			while not _stack.is_empty():
				var _c:Vector2i = _stack.pop_back()
				if _region.size() > LIMIT:
					_escaped = true
					break
				for b:int in _DELTAS:
					var _n:Vector2i = _c + _DELTAS[b]
					if floor_set.has(_n) or _region.has(_n):
						continue
					_region[_n] = true
					_stack.push_back(_n)
			for c:Vector2i in _region:
				_checked[c] = true
			if not _escaped:
				for c:Vector2i in _region:
					_gaps[c] = true
	return _gaps


## Rewrite every painted cell on tilemap_layer to the correct atlas tile.
func autotile()->void:
	for cell:Vector2i in tilemap_layer.get_used_cells():
		var _src:int = tilemap_layer.get_cell_source_id(cell)
		if _src == -1:
			continue
		var _atlas:Vector2i = _pick_atlas(cell)
		tilemap_layer.set_cell(cell, _src, _atlas)


## Reset painted cells back to the neutral marker so a clean re-paint/re-fix is possible.
func reset_to_marker()->void:
	for cell:Vector2i in tilemap_layer.get_used_cells():
		var _src:int = tilemap_layer.get_cell_source_id(cell)
		if _src == -1:
			continue
		tilemap_layer.set_cell(cell, _src, marker_atlas)


## Choose the atlas coord for one cell. Holes use the same-layer hole mask; walls are
## chosen purely from the surrounding floor topology (see _pick_wall()).
func _pick_atlas(cell:Vector2i)->Vector2i:
	if layer_kind == LayerKind.HOLE:
		var _hole_mask:int = 0
		for bit:int in _DELTAS:
			if tilemap_layer.get_cell_source_id(cell + _DELTAS[bit]) != -1:
				_hole_mask |= bit
		return _pick_hole(cell, _hole_mask)

	# WALL. Optional safety: leave cells untouched while painting a sample for table tuning.
	if !wall_table_ready:
		return tilemap_layer.get_cell_atlas_coords(cell)
	return _pick_wall(cell)


## True if the cell at the given map offset from `cell` is also a hole.
func _hole_at(cell:Vector2i, dx:int, dy:int)->bool:
	return tilemap_layer.get_cell_source_id(cell + Vector2i(dx, dy)) != -1


## Hole atlas from hole-neighbor shape + back-diagonals. Rule verified 28/28 vs room_0_test.
## The two back sides BL and TL decide the edge; the top-left back-diagonal (-1,-1) selects
## the "continuing" variant; an interior strip open on both back-diagonals uses 1:0.
func _pick_hole(cell:Vector2i, hole_mask:int)->Vector2i:
	var _has_bl:bool = (hole_mask & SIDE_BL) != 0
	var _has_tl:bool = (hole_mask & SIDE_TL) != 0
	var _diag_tl:bool = _hole_at(cell, -1, -1)
	if _has_bl and _has_tl:
		# Interior. Thin diagonal strip (both back-diagonals empty) uses the 1:0 variant.
		if not _diag_tl and not _hole_at(cell, 1, 1):
			return HOLE_INTERIOR_STRIP
		return HOLE_INTERIOR
	if _has_bl:
		return HOLE_BL_CONT if _diag_tl else HOLE_BL
	if _has_tl:
		return HOLE_TL_CONT if _diag_tl else HOLE_TL
	return HOLE_NONE


## True if a floor tile exists at the given map offset from `cell`.
func _floor_at(cell:Vector2i, dx:int, dy:int)->bool:
	return floor_layer.get_cell_source_id(cell + Vector2i(dx, dy)) != -1


## Wall atlas from the surrounding FLOOR topology alone. Verified 200/200 vs room_0_test.
## A wall tile wraps a floor cell, so its variant is a pure function of nearby floor — the
## wall-neighbour shape is irrelevant. Bits read: S=self overlaps floor, TR=(+1,0),
## BR=(0,+1), and the BR-diagonal dBR=(+1,+1). S selects overlap-vs-offset art; TR/BR pick
## the run/corner shape; dBR is the brick-vs-mono variant selector.
func _pick_wall(cell:Vector2i)->Vector2i:
	var _s:bool = _floor_at(cell, 0, 0)
	var _tr:bool = _floor_at(cell, 1, 0)
	var _br:bool = _floor_at(cell, 0, 1)
	var _dbr:bool = _floor_at(cell, 1, 1)
	if _s:                                            # wall overlaps a floor cell
		if _tr and _br:
			return Vector2i(3, 2)
		if _tr:
			return Vector2i(2, 1) if _dbr else Vector2i(1, 2)
		if _br:
			return Vector2i(3, 1) if _dbr else Vector2i(0, 2)
		return Vector2i(1, 0)
	# wall sits in the empty cell offset from the floor
	if _tr and _br:
		return Vector2i(2, 2)
	if _tr:
		return Vector2i(0, 1) if _dbr else Vector2i(3, 0)
	if _br:
		return Vector2i(1, 1) if _dbr else Vector2i(2, 0)
	return Vector2i(0, 0)
