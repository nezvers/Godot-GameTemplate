## Shared room progress: cleared rooms and sections, opened loot boxes.
class_name RoomProgressComponent
extends RunSaveComponent

const ROOM_STATE:RoomStateResource = preload("res://addons/top_down/resources/global_resources/room_state_resource.tres")

@export var cleared_rooms:PackedStringArray
## room_id -> PackedInt32Array of cleared section indices
@export var cleared_sections:Dictionary
@export var looted:PackedStringArray

func id()->StringName:
	return &"room_progress"

func capture()->void:
	var _state:RoomStateResource = ROOM_STATE
	cleared_rooms = PackedStringArray()
	for _id:Variant in _state.cleared_rooms:
		cleared_rooms.append(String(_id))
	cleared_sections = {}
	for _room:Variant in _state.cleared_sections:
		var _indices:PackedInt32Array = PackedInt32Array()
		for _index:Variant in _state.cleared_sections[_room]:
			_indices.append(int(_index))
		cleared_sections[String(_room)] = _indices
	looted = PackedStringArray()
	for _key:Variant in _state.looted:
		looted.append(String(_key))

func apply()->void:
	var _state:RoomStateResource = ROOM_STATE
	_state.cleared_rooms.clear()
	_state.cleared_sections.clear()
	_state.looted.clear()
	for _id:String in cleared_rooms:
		_state.cleared_rooms[StringName(_id)] = true
	for _room:Variant in cleared_sections:
		var _set:Dictionary = {}
		for _index:Variant in cleared_sections[_room]:
			_set[int(_index)] = true
		_state.cleared_sections[StringName(_room)] = _set
	for _key:String in looted:
		_state.looted[_key] = true
	_state.updated.emit()
