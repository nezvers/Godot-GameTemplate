# Tiling: generating colliders and scenes

Paint tiles on a `TileMapLayer`, then trigger a generator node that reads each tile's
custom data and bakes the result into the scene file. Two `@tool` generators handle two
custom data layers: `TileCollisionGenerator` (physics colliders) and
`BlockWallGenerator` (scene instances). Painting only places art; nothing collides or
spawns until you generate.

## Floor-aware visual autotiling
`FloorLayer` uses Godot's built-in terrain brush. `ObstacleLayer` (holes) and
`WallLayer_Ysorted` (walls) instead use a custom `@tool` node,
`TileVisualAutotiler` (`addons/great_games_library/nodes/utility/TileVisualAutotiler.gd`).

Why custom: built-in terrain is single-layer and picks one tile per neighbor-fingerprint.
Walls/holes here need the **FloorLayer relationship**. A wall tile wraps a floor cell, so
its variant (shape + brick "inside-out" vs mono-color "outside-in") is a pure function of
the surrounding floor topology, not of neighbouring walls. Terrain cannot express that, so
a small custom autotiler reads the floor (and, for holes, the painted layer).

Workflow: paint *where* a wall/hole goes using any single marker tile (no need to pick
orientation), then tick **Fix Visual** on the layer's `TileVisualAutotiler`. It rewrites
each painted wall cell to the correct atlas tile purely from the surrounding floor: whether
the wall overlaps a floor cell (S), which horizontal sides (TR/BR) carry floor, and the
BR-diagonal (dBR) which selects the brick-vs-mono variant. It preserves each cell's source id so
`collider_offset` / `scene_path` custom data stays intact. Then run the Generate step below.

Wiring (`addons/top_down/scenes/levels/room_template.tscn`): `tilemap_layer` = the layer,
`floor_layer` = NodePath to `FloorLayer`, `layer_kind` = WALL or HOLE, `marker_atlas` =
the neutral tile you paint with. `Confirm Clear` + `Clear` resets painted cells back to
`marker_atlas` for a clean re-paint.

The atlas mapping lives in clearly-commented constants at the top of the script — tweak a
coord there if a variant comes out flipped. The BlockWall marker tile (walls tileset,
source 1) is placed manually and is ignored by the autotiler.

It is re-runnable (idempotent): always recomputes from the current markers + floor. Later
this Fix Visual pass may be folded into the Generate Colliders action; for now it is a
separate button.

### Generate from floor
Two more buttons build markers straight from the FloorLayer, then run Fix Visual:
- **Add missing** — fills only empty boundary cells, leaving anything already painted.
- **Regenerate** — clears this layer first, then rebuilds the whole boundary.

Both first classify every floor-adjacent empty cell: a connected empty region fully
enclosed by floor is a **gap**; one that reaches open space is **exterior**.

WALL layer: rings each floor island's **exterior** edge only (never into a gap). An outer
edge open toward TL or BL places the wall in the empty cell outside; toward TR or BR places
it on the floor cell (overlap). Two extra passes close corners: a bridge fills the up-left
diagonal where a floor's TL and BL neighbours both became walls, and an interior-corner pass
fills a ringed floor cell whose TR and BR neighbours both became walls *and* whose BL and TL
floor states match (both floor or both empty — differing means a perimeter cell, left alone).
Placement and visual selection are both verified 200/200 vs room_0_test (including the
tightly-packed floor islands). Decorative stubs are not auto-generated — add those by hand.

HOLE layer: fills the **gap cells themselves** (the enclosed empty space inside the floor),
not the surrounding floor. Verified 28/28 vs room_0_test.

## TileCollisionGenerator
`addons/great_games_library/nodes/Navigation/TileCollisionGenerator.gd`

Bakes `CollisionPolygon2D` children for walls and hole obstacles. Sits under the
layer's `StaticBody2D` (e.g. `ObstacleLayer/StaticBody2D`,
`WallLayer_Ysorted/StaticBody2D`).

Reads custom data `collider_offset` (`PackedVector2Array`) — a tile may emit several
offsets. Every polygon uses the diamond `tile_shape`.

- Tick `generate_colliders` to bake.
- Wiring: `tilemap_layer`, `static_body`, `tile_shape`, `data_name` (default
  `collider_offset`).

## BlockWallGenerator
`addons/great_games_library/nodes/utility/BlockWallGenerator.gd`

Spawns scene instances for tiles carrying a `scene_path` — block walls, hole obstacle
scenes. Editor-time twin of the runtime `TileSpawner`. Sits under the layer; `container`
is usually the `TileMapLayer` itself.

Reads custom data `scene_path` (`String`), loads and instances the scene, names it
`<SceneBase><N>`, parents to `container`, and sets `owner` so it saves into the scene.

- Tick `generate` to spawn.
- `erase_placeholder` (default `true`) removes the marker tile after spawning so its art
  doesn't overlap the instance.
- `spawn_offset` (default `Vector2(16, 8)`) corrects iso half-tile misalignment — tune
  in the inspector if the spawned scene sits off-grid.
- Wiring: `tilemap_layer`, `container`, `data_name` (default `scene_path`),
  `erase_placeholder`, `spawn_offset`.

## Clearing
Both nodes clear in two steps: tick `Confirm Clear`, then tick `Clear`. It disarms
`confirm_clear` after each clear, so a second clear needs re-confirming.
`BlockWallGenerator` restores the erased placeholder tiles on clear, so the layout
survives a clear/regenerate cycle.

Re-running generate cleans up prior output first — safe to re-bake after repainting.

## Walls, block walls, holes
- Static walls & holes → painted tiles with `collider_offset` → `TileCollisionGenerator`
  bakes static colliders.
- Block walls (animated unlock doors) → painted `block_wall.tscn` marker tile
  (`scene_path` custom data) → `BlockWallGenerator` spawns `BlockWall` instances.
- Layers: `ObstacleLayer` holds holes; `WallLayer_Ysorted` holds walls and block walls
  (y-sorted).

Marker and custom data live in the tilesets:
`resources/tilesets/tileset_isometric_walls.tres` (BlockWall marker, `collider_offset`
and `scene_path`) and `resources/tilesets/tileset_isometric_holes.tres`.
