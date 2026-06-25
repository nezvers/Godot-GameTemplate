## Session-scoped progression state for the mini-game.
## Tracks which rooms are cleared and the currently active room id.
## Held alive across scene changes by being the same shared .tres referenced
## from every room (Godot caches the loaded resource).
class_name RoomStateResource
extends Resource

## Emitted when current room or cleared set changes, so HUD can refresh.
signal updated

## Set of cleared room ids (Dictionary used as a set: id -> true).
var cleared_rooms: Dictionary = {}

## Per-room cleared section indices: room_id -> Dictionary(section_index -> true).
## Lets a partially-cleared room resume only its uncleared sections on return.
var cleared_sections: Dictionary = {}

## Id of the room the player is currently in.
var current_room_id: StringName = &""

func set_current(id: StringName) -> void:
	if current_room_id == id:
		return
	current_room_id = id
	updated.emit()

func is_cleared(id: StringName) -> bool:
	return cleared_rooms.has(id)

func mark_cleared(id: StringName) -> void:
	if cleared_rooms.has(id):
		return
	cleared_rooms[id] = true
	updated.emit()

func is_section_cleared(room_id: StringName, index: int) -> bool:
	var _sections: Dictionary = cleared_sections.get(room_id, {})
	return _sections.has(index)

func mark_section_cleared(room_id: StringName, index: int) -> void:
	var _sections: Dictionary = cleared_sections.get(room_id, {})
	if _sections.has(index):
		return
	_sections[index] = true
	cleared_sections[room_id] = _sections
	updated.emit()
