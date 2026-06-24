class_name ArenaDoorBlock
extends Node

## Wall behavior relative to its bound arena section:
## BARRIER - down by default, raises (seals) while the section's fight is active,
##           lowers again when the section clears. (Classic arena seal.)
## GATE    - up by default, lowers permanently once the section clears, opening
##           access to the next area.
enum WallMode {BARRIER, GATE}

@export var mode:WallMode = WallMode.BARRIER

## The arena section whose state drives this wall (node in the room scene).
@export var section:ArenaSection

@export var astargrid_resource:AstarGridResource
@export var position_node:Node2D
@export var animation_player:AnimationPlayer
@export var animation_on:StringName
@export var animation_off:StringName

enum WallState {OFF, ON}
var state:WallState = WallState.OFF

func _ready()->void:
	# Pull config from the root BlockWall if present, so a room can set section/
	# mode on the instance root without editing this inner node.
	var _root:BlockWall = owner as BlockWall
	if _root == null:
		_root = get_parent() as BlockWall
	if _root != null:
		section = _root.section
		mode = _root.mode

	# Unassigned wall stays inert (default lowered) instead of crashing, so a
	# room can wire walls incrementally.
	if section == null:
		return
	match mode:
		WallMode.BARRIER:
			section.fight_started.connect(_set_raised.bind(true))
			section.cleared.connect(_set_raised.bind(false))
			# Deferred so the AstarGrid2D value is populated before first apply.
			_set_raised.call_deferred(section.fight_active)
		WallMode.GATE:
			# Raised by default until the section is cleared.
			section.cleared.connect(_set_raised.bind(false))
			_set_raised.call_deferred(!section.is_cleared)

func _set_raised(raised:bool)->void:
	if astargrid_resource.value == null:
		return

	var _new_state:WallState = WallState.ON if raised else WallState.OFF
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
