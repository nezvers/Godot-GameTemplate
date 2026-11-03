## A door that stays shut until a room is cleared. Boss rooms get one back to the
## campaign's first hub and a victory exit, both waiting for the boss room itself;
## the hub gets one per boss room, waiting for that room, so killing a boss opens a
## two-way shortcut for the rest of the run.
class_name Portal
extends SceneEntry

## Room id (RoomController.room_id) whose clearing opens this portal.
@export var open_when_cleared:StringName
@export var room_state_resource:RoomStateResource
## Frame 0 dormant, the rest the open vortex loop.
@export var sprite:Sprite2D
@export var frame_time:float = 0.1

var is_open:bool
var _frame_left:float

func _ready()->void:
	super._ready()
	assert(room_state_resource != null)
	assert(!String(open_when_cleared).is_empty())
	room_state_resource.updated.connect(_refresh)
	set_open(room_state_resource.is_cleared(open_when_cleared))

func _exit_tree()->void:
	if room_state_resource.updated.is_connected(_refresh):
		room_state_resource.updated.disconnect(_refresh)

func _refresh()->void:
	if !is_open && room_state_resource.is_cleared(open_when_cleared):
		set_open(true)

## Closed portals don't monitor, so walking over them does nothing.
func set_open(value:bool)->void:
	is_open = value
	set_deferred("monitoring", value)
	if sprite != null:
		sprite.frame = 1 if value else 0

func _process(delta:float)->void:
	if !is_open || sprite == null:
		return
	_frame_left -= delta
	if _frame_left > 0.0:
		return
	_frame_left = frame_time
	sprite.frame = 1 + sprite.frame % (sprite.hframes - 1)
