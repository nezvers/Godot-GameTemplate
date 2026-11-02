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

enum LayerKind { WALL, HOLE, FLOOR }

## Recompute each painted cell's tile art from the surrounding FloorLayer + same-layer
## neighbours. Run after painting markers or editing the floor. On a WALL/HOLE layer it first
## fixes the FloorLayer's own edge tiles too (see fix_floor()).
@export var fix_visual:bool : set = set_fix_visual

@export_group("Generate from floor")
## Add marker tiles where the floor island boundary needs them, WITHOUT touching existing
## cells, then run Fix Visual. WALL: rings every floor island's outer edge. HOLE: fills the
## enclosed gap cells inside the floor.
@export var add_missing:bool : set = set_add_missing
## Like Add Missing but first erases this layer, rebuilding the whole boundary from scratch.
@export var regenerate:bool : set = set_regenerate

@export_group("Clear tiles")
## Step 1: tick to arm. Step 2: tick Clear to remove every painted cell from this layer.
@export var confirm_clear:bool = false
## Erase all painted cells from this layer (leaves an empty layer). Requires Confirm Clear first.
@export var clear:bool : set = set_clear

@export_group("")
## This wall/hole layer — the tiles this node paints and rewrites.
@export var tilemap_layer:TileMapLayer
## FloorLayer used to decide which side the floor is on and where boundaries go (cross-layer input).
@export var floor_layer:TileMapLayer
## WALL = ring floor islands' outer edge; HOLE = fill enclosed gaps inside the floor;
## FLOOR = normalise the floor layer's own edge art from its 4 diagonal neighbours (Fix
## Visual only — the Generate-from-floor buttons do not apply to FLOOR).
@export var layer_kind:LayerKind = LayerKind.WALL
## Atlas coord stamped when placing a plain marker before Fix Visual / Generate from floor.
@export var marker_atlas:Vector2i = Vector2i(0, 2)
## Safety: while false, WALL cells are left untouched by Fix Visual. The table is verified
## 200/200 against room_0_test, so this defaults true; flip off only to paint a new wall
## sample without the autotiler overwriting it. Holes are unaffected by this flag.
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

# Enclosed gap cells of the floor, refreshed by each FLOOR autotile() pass.
var _floor_gaps:Dictionary = {}

# --- ATLAS TABLES ----------------------------------------------------------------------
# HOLE rule. The two back sides (BL, TL) decide the edge class; the top-left back-diagonal
# (-1,-1) selects a "continuing" variant where the hole wraps diagonally behind. The interior
# case is floor-driven (like walls): a floor tile up-left means the room edge wraps behind,
# selecting the 1:0 strip/corner variant. See _pick_hole().
#   neither BL nor TL          -> 0:0   (front corner / cap)
#   BL only                    -> 0:1 , or 1:1 when TL-diagonal is also hole
#   TL only                    -> 2:0 , or 2:1 when TL-diagonal is also hole
#   both BL and TL             -> 0:2 , or 1:0 when TL-diagonal (-1,-1) is a floor tile
const HOLE_NONE := Vector2i(0, 0)
const HOLE_BL := Vector2i(0, 1)
const HOLE_BL_CONT := Vector2i(1, 1)
const HOLE_TL := Vector2i(2, 0)
const HOLE_TL_CONT := Vector2i(2, 1)
const HOLE_INTERIOR := Vector2i(0, 2)
const HOLE_INTERIOR_STRIP := Vector2i(1, 0)

# WALL rule: the tile is a pure function of the surrounding FLOOR topology (a wall wraps a
# floor cell), verified 200/200 against the hand-made room_0_test layout. See _pick_wall().
#
# FLOOR rule. Godot's built-in terrain mis-fires here because the art only encodes which of
# the four diagonal SIDES carry a raised edge, yet the tileset was authored with 8-bit
# corner+side peering — most fingerprints undefined, so the brush substitutes a wrong
# nearest-match that flips as neighbours change. This picker works from the art itself: each
# edge tile lists the screen sides it draws an edge on, and a cell gets the tile whose edges
# are exactly its non-floor sides. See _pick_floor().
#
# NOTE the SIDE_* names above are legacy and rotated a quarter turn from the screen. The real
# directions of this layout (TileMapLayer.map_to_local) are used for the floor only:
const _SCREEN_TL := Vector2i(-1, 0)
const _SCREEN_TR := Vector2i(0, -1)
const _SCREEN_BL := Vector2i(0, 1)
const _SCREEN_BR := Vector2i(1, 0)
const _FLOOR_SIDES := {8: _SCREEN_TL, 4: _SCREEN_TR, 2: _SCREEN_BL, 1: _SCREEN_BR}

# Atlas coord -> screen sides its edge is drawn on (bits TL=8 TR=4 BL=2 BR=1), measured from
# tileset_isometric_floor.png. The art has no tile with edges on three or four sides or on two
# opposite sides (a one-tile-wide strip); those cells get the best partial match instead.
const _FLOOR_EDGES := {
	Vector2i(0, 3): 0b0000,  # plain fill, no edge
	Vector2i(0, 1): 0b1000,  # TL
	Vector2i(1, 1): 0b0100,  # TR
	Vector2i(1, 2): 0b0010,  # BL
	Vector2i(0, 2): 0b0001,  # BR
	Vector2i(0, 0): 0b1100,  # TL,TR
	Vector2i(3, 0): 0b1010,  # TL,BL
	Vector2i(2, 0): 0b0101,  # TR,BR
	Vector2i(1, 0): 0b0011,  # BL,BR
}

# Inner corners: all four sides are floor but one diagonal cell is empty, so the tile vertex
# pointing at it gets a small edge notch. Key = map offset of the empty diagonal.
const _FLOOR_CORNERS := {
	Vector2i(-1, -1): Vector2i(2, 2),  # top vertex
	Vector2i(1, -1): Vector2i(3, 1),   # right vertex
	Vector2i(1, 1): Vector2i(3, 2),    # bottom vertex
	Vector2i(-1, 1): Vector2i(2, 1),   # left vertex
}

# Interior tiles the artist may hand-place on a fully-surrounded cell — plain-fill variants
# plus decorative "cracked" floors. Fix Visual leaves these untouched so decoration survives
# a re-run (unless the cell needs an inner corner).
const _FLOOR_INTERIOR_KEEP := [
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
]
# ---------------------------------------------------------------------------------------


func set_fix_visual(_value:bool)->void:
	if !is_inside_tree() or !Engine.is_editor_hint():
		return
	if tilemap_layer == null or floor_layer == null:
		push_warning("TileVisualAutotiler: assign tilemap_layer and floor_layer.")
		return
	fix_floor()
	autotile()


func set_clear(_value:bool)->void:
	if !is_inside_tree() or !Engine.is_editor_hint():
		return
	if !confirm_clear:
		push_warning("TileVisualAutotiler: tick 'Confirm Clear' before clearing.")
		return
	confirm_clear = false
	notify_property_list_changed()
	erase_tiles()


func set_add_missing(_value:bool)->void:
	if !is_inside_tree() or !Engine.is_editor_hint():
		return
	if tilemap_layer == null or floor_layer == null:
		push_warning("TileVisualAutotiler: assign tilemap_layer and floor_layer.")
		return
	fix_floor()
	generate_from_floor()
	autotile()


func set_regenerate(_value:bool)->void:
	if !is_inside_tree() or !Engine.is_editor_hint():
		return
	if tilemap_layer == null or floor_layer == null:
		push_warning("TileVisualAutotiler: assign tilemap_layer and floor_layer.")
		return
	fix_floor()
	tilemap_layer.clear()
	generate_from_floor()
	autotile()


## WALL/HOLE: run the FLOOR rule on floor_layer first, so one Fix Visual click also fixes the
## floor edges. The FloorLayer's own autotiler sits inside the instanced floor_layer.tscn and
## is hidden in room scenes. Floor fixing only swaps atlas coords, so walls/holes don't change.
func fix_floor()->void:
	if layer_kind == LayerKind.FLOOR or floor_layer == null or floor_layer == tilemap_layer:
		return
	var _floor_fixer:Node = get_script().new()
	_floor_fixer.tilemap_layer = floor_layer
	_floor_fixer.floor_layer = floor_layer
	_floor_fixer.layer_kind = LayerKind.FLOOR
	_floor_fixer.autotile()
	_floor_fixer.free()


## Source id used when placing new marker cells (first source on the layer's tileset).
func _marker_source()->int:
	var _ts:TileSet = tilemap_layer.tile_set
	if _ts == null or _ts.get_source_count() == 0:
		return -1
	return _ts.get_source_id(0)


## Source for a marker generated from floor cell f: a painted floor look (mossy, bloody...)
## carries over when this layer's tileset has a source with the same id, else the default.
func _floor_look_source(f:Vector2i, default_src:int)->int:
	var _floor_src:int = floor_layer.get_cell_source_id(f)
	if _floor_src == -1:
		return default_src
	var _ts:TileSet = tilemap_layer.tile_set
	if _ts.has_source(_floor_src) and _floor_src != floor_layer.tile_set.get_source_id(0):
		return _floor_src
	return default_src


## Look for a hole gap: the first neighbouring floor cell with a painted look decides.
func _gap_look_source(gap:Vector2i, default_src:int)->int:
	for bit:int in _DELTAS:
		var _src:int = _floor_look_source(gap + _DELTAS[bit], default_src)
		if _src != default_src:
			return _src
	return default_src


## Place marker tiles along the floor boundary. Existing cells are never overwritten.
## WALL: rings every floor island's outer edge. Placement (measured from room_0_test):
## a floor edge open toward TL or BL puts the wall in the empty neighbour cell (outside);
## open toward TR or BR puts the wall on the floor cell itself (overlap).
## HOLE: marks floor cells that border an interior empty region (a gap enclosed by floor).
func generate_from_floor()->void:
	if layer_kind == LayerKind.FLOOR:
		push_warning("TileVisualAutotiler: Generate-from-floor does not apply to FLOOR kind; paint floor tiles then tick Fix Visual.")
		return
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
					tilemap_layer.set_cell(_target, _floor_look_source(f, _src), marker_atlas)
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
				tilemap_layer.set_cell(_diag, _floor_look_source(f, _src), marker_atlas)
		# Interior corner: an interior floor cell whose TR and BR neighbours both became
		# walls (the overlap edges) closes a corner — but only when its BL and TL back
		# sides are symmetric (both floor or both empty). When exactly one of BL/TL is
		# floor the cell sits on the perimeter and must stay empty. Also skip cells whose
		# BR-diagonal is floor: those are fully enclosed interior tiles, not corners, and
		# would get a spurious wall (matches _pick_wall, where dBR is the corner selector).
		for f:Vector2i in _floor_cells:
			if tilemap_layer.get_cell_source_id(f) != -1:
				continue
			var _tr:Vector2i = f + _DELTAS[SIDE_TR]
			var _br:Vector2i = f + _DELTAS[SIDE_BR]
			if tilemap_layer.get_cell_source_id(_tr) == -1 or tilemap_layer.get_cell_source_id(_br) == -1:
				continue
			if _floor_set.has(f + _DELTAS[SIDE_BL]) != _floor_set.has(f + _DELTAS[SIDE_TL]):
				continue
			if _floor_set.has(f + Vector2i(1, 1)):
				continue
			tilemap_layer.set_cell(f, _floor_look_source(f, _src), marker_atlas)
	else:
		# HOLE: fill the enclosed gap cells themselves (the empty space inside the floor).
		for gap:Vector2i in _gap_set:
			if tilemap_layer.get_cell_source_id(gap) == -1:
				tilemap_layer.set_cell(gap, _gap_look_source(gap, _src), marker_atlas)


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
	if layer_kind == LayerKind.FLOOR:
		# Holes are the empty gaps enclosed by floor: edges facing them win when the art
		# can't draw every side of a cell.
		var _floor_cells:Array[Vector2i] = tilemap_layer.get_used_cells()
		var _floor_set:Dictionary = {}
		for c:Vector2i in _floor_cells:
			_floor_set[c] = true
		_floor_gaps = _collect_gaps(_floor_cells, _floor_set)
	for cell:Vector2i in tilemap_layer.get_used_cells():
		var _src:int = tilemap_layer.get_cell_source_id(cell)
		if _src == -1:
			continue
		var _atlas:Vector2i = _pick_atlas(cell)
		tilemap_layer.set_cell(cell, _src, _atlas)


## Erase every painted cell from this layer so a clean re-paint/regenerate is possible.
func erase_tiles()->void:
	for cell:Vector2i in tilemap_layer.get_used_cells():
		tilemap_layer.erase_cell(cell)


## Choose the atlas coord for one cell. Holes use the same-layer hole mask; walls are
## chosen purely from the surrounding floor topology (see _pick_wall()).
func _pick_atlas(cell:Vector2i)->Vector2i:
	if layer_kind == LayerKind.FLOOR:
		return _pick_floor(cell)
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


## Hole atlas from hole-neighbor shape + back-diagonals. The two back sides BL and TL decide
## the edge; the top-left back-diagonal (-1,-1) selects the "continuing" variant. The interior
## case is floor-driven: a floor tile at the up-left back-diagonal uses the 1:0 strip variant.
func _pick_hole(cell:Vector2i, hole_mask:int)->Vector2i:
	var _has_bl:bool = (hole_mask & SIDE_BL) != 0
	var _has_tl:bool = (hole_mask & SIDE_TL) != 0
	var _diag_tl:bool = _hole_at(cell, -1, -1)
	if _has_bl and _has_tl:
		# Interior. Floor-driven, like walls: when the up-left back-diagonal is a floor
		# tile the room edge wraps behind here, so use the 1:0 strip/corner variant;
		# otherwise the cell is solid interior (0:2).
		if _floor_at(cell, -1, -1):
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


## Floor atlas from the four side neighbours on THIS layer (the floor is both the painted
## layer and its own topology source). The edge goes on every side whose neighbour is not
## floor, and never on a side that has floor. When the art has no tile for that exact set of
## sides, use the tile covering the most of them, preferring sides that face a hole.
func _pick_floor(cell:Vector2i)->Vector2i:
	var _open:int = 0
	var _hole:int = 0
	for bit:int in _FLOOR_SIDES:
		var _n:Vector2i = cell + _FLOOR_SIDES[bit]
		if tilemap_layer.get_cell_source_id(_n) == -1:
			_open |= bit
			if _floor_gaps.has(_n):
				_hole |= bit
	if _open == 0:
		return _pick_floor_interior(cell)
	var _best:Vector2i = Vector2i(0, 3)
	var _best_score:int = -1
	for atlas:Vector2i in _FLOOR_EDGES:
		var _edges:int = _FLOOR_EDGES[atlas]
		if _edges & ~_open:
			continue  # would draw an edge against a floor neighbour
		if _edges == _open:
			return atlas
		var _score:int = 2 * _bit_count(_edges & _hole) + _bit_count(_edges)
		if _score > _best_score:
			_best_score = _score
			_best = atlas
	return _best


## Fully-surrounded cell: an inner corner where a diagonal is empty (a hole-facing one wins),
## else keep a hand-placed fill or cracked decoration, else plain fill.
func _pick_floor_interior(cell:Vector2i)->Vector2i:
	var _corner:Vector2i = Vector2i(-1, -1)
	for offset:Vector2i in _FLOOR_CORNERS:
		if tilemap_layer.get_cell_source_id(cell + offset) != -1:
			continue
		if _corner == Vector2i(-1, -1) or _floor_gaps.has(cell + offset):
			_corner = _FLOOR_CORNERS[offset]
	if _corner != Vector2i(-1, -1):
		return _corner
	var _cur:Vector2i = tilemap_layer.get_cell_atlas_coords(cell)
	if _cur in _FLOOR_INTERIOR_KEEP:
		return _cur
	return Vector2i(0, 3)


func _bit_count(value:int)->int:
	var _count:int = 0
	while value:
		_count += value & 1
		value >>= 1
	return _count


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
