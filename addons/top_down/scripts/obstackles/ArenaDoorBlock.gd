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

## Emitted after set_raised changes the state (pistons save on it)
signal state_changed(raised:bool)

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
			section.fight_started.connect(set_raised.bind(true))
			section.cleared.connect(set_raised.bind(false))
			# Deferred so the AstarGrid2D value is populated before first apply.
			set_raised.call_deferred(section.fight_active)
		WallMode.GATE:
			# Raised by default until the section is cleared.
			section.cleared.connect(set_raised.bind(false))
			set_raised.call_deferred(!section.is_cleared)

## Public so section-less walls (home base pistons) can be driven by code.
## instant skips the animation (restoring saved state).
func set_raised(raised:bool, instant:bool = false)->void:
	if astargrid_resource.value == null:
		return

	var _new_state:WallState = WallState.ON if raised else WallState.OFF
	if _new_state == state:
		return
	state = _new_state

	var _tile_pos:Vector2i = astargrid_resource.tilemap_layer.local_to_map(position_node.global_position)

	match state:
		WallState.ON:
			_play(animation_on, instant)
			_set_solid(_tile_pos, true)
		WallState.OFF:
			_play(animation_off, instant)
			_set_solid(_tile_pos, false)
	state_changed.emit(raised)

func is_raised()->bool:
	return state == WallState.ON

func _play(animation:StringName, instant:bool)->void:
	animation_player.play(animation)
	if instant:
		animation_player.seek(animation_player.current_animation_length, true)

func _set_solid(tile_pos:Vector2i, solid:bool)->void:
	if astargrid_resource.value.is_in_boundsv(tile_pos):
		astargrid_resource.value.set_point_solid(tile_pos, solid)
