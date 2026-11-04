## A door that stays shut and hidden until a room is cleared. Boss rooms get one back to the
## campaign's first hub and a victory exit, both waiting for the boss room itself;
## the hub gets one per boss room, waiting for that room, so killing a boss opens a
## two-way shortcut for the rest of the run.
## A label above names where it leads; the victory exit reads EXTRACT and glows green.
class_name Portal
extends SceneEntry

## Tag of the victory exit (build_rooms.gd VICTORY).
const EXTRACT_TAG:String = "victory"
const EXTRACT_TEXT:String = "EXTRACT"
const EXTRACT_TEXTURE:Texture2D = preload("res://addons/top_down/assets/images/misc/portal_extract_32x32_strip6.png")
const EXTRACT_COLOR:Color = Color(0.55, 1.0, 0.45)

## Room id (RoomController.room_id) whose clearing opens this portal.
@export var open_when_cleared:StringName
@export var room_state_resource:RoomStateResource
## Frame 0 dormant, the rest the open vortex loop.
@export var sprite:Sprite2D
@export var frame_time:float = 0.1
## Name of the room it leads to, written by build_rooms.gd.
@export var destination_name:String
@export var label:Label

var is_open:bool
var _frame_left:float

func _ready()->void:
	super._ready()
	assert(room_state_resource != null)
	assert(!String(open_when_cleared).is_empty())
	_setup_look()
	room_state_resource.updated.connect(_refresh)
	set_open(room_state_resource.is_cleared(open_when_cleared))

func is_extract()->bool:
	return tag == EXTRACT_TAG

func _setup_look()->void:
	if is_extract() && sprite != null:
		sprite.texture = EXTRACT_TEXTURE
	if label == null:
		return
	label.text = EXTRACT_TEXT if is_extract() else destination_name.to_upper()
	if is_extract():
		label.add_theme_color_override("font_color", EXTRACT_COLOR)

func _exit_tree()->void:
	if room_state_resource.updated.is_connected(_refresh):
		room_state_resource.updated.disconnect(_refresh)

func _refresh()->void:
	if !is_open && room_state_resource.is_cleared(open_when_cleared):
		set_open(true)

## Closed portals are hidden and don't monitor, so walking over them does nothing.
func set_open(value:bool)->void:
	is_open = value
	visible = value
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
