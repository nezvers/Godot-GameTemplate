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

## Opened one-use containers (loot boxes), keyed "<room scene>:<node name>".
var looted: Dictionary = {}

## Id of the room the player is currently in.
var current_room_id: StringName = &""

## A new campaign run starts with every room and container fresh.
func reset_resource() -> void:
	cleared_rooms.clear()
	cleared_sections.clear()
	looted.clear()
	current_room_id = &""
	updated.emit()

func is_looted(key: String) -> bool:
	return looted.has(key)

func mark_looted(key: String) -> void:
	looted[key] = true

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

## Sections cleared across every room this session (the victory screen's "rooms").
func cleared_section_count() -> int:
	var _count: int = 0
	for _sections: Dictionary in cleared_sections.values():
		_count += _sections.size()
	return _count
