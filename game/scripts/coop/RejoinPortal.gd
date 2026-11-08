## Home base portal back into the host's game, there while this machine is a
## co-op ghost (left with "I will return"). Walking in rejoins wherever the host
## is now; mid-fight the guest waits at the host's door (WaitingAtDoor).
## While the host is between rooms or on a menu screen it stays shut; after the
## host's victory it opens again once the host is back in its home base.
## Placed by HomeBase; built in code from the portal's sprite strip.
class_name RejoinPortal
extends Area2D

const TEXTURE:Texture2D = preload("res://addons/top_down/assets/images/misc/portal_32x32_strip6.png")
const OPEN_COLOR:Color = Color(0.6, 0.85, 1.0)
const SHUT_COLOR:Color = Color(0.6, 0.6, 0.65)
const FRAME_TIME:float = 0.1

var sprite:Sprite2D
var label:Label
var _frame_left:float
## Only after the player has stood outside it once (it may spawn on top of it).
var _armed:bool
var _used:bool

func _init()->void:
	name = "RejoinPortal"
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	var _shape:CollisionPolygon2D = CollisionPolygon2D.new()
	_shape.polygon = PackedVector2Array([Vector2(0, -8), Vector2(-16, 0), Vector2(0, 8), Vector2(16, 0)])
	add_child(_shape)
	sprite = Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.hframes = 6
	sprite.centered = false
	sprite.position = Vector2(-16, -24)
	add_child(sprite)
	label = Label.new()
	label.z_index = 10
	label.offset_left = -60
	label.offset_right = 60
	label.offset_top = -34
	label.offset_bottom = -25
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)

func _ready()->void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Net.ghost_status_changed.connect(_refresh)
	Net.state_changed.connect(_refresh)
	_refresh()
	_arm_if_clear.call_deferred()

func _exit_tree()->void:
	if Net.ghost_status_changed.is_connected(_refresh):
		Net.ghost_status_changed.disconnect(_refresh)
	if Net.state_changed.is_connected(_refresh):
		Net.state_changed.disconnect(_refresh)

func is_open()->bool:
	return Net.is_ghost() && NetPlayers.can_rejoin(Net.ghost_host_room)

func _refresh()->void:
	if !Net.is_ghost() && !_used:
		# the link is gone (host left, kicked): nothing to go back to
		queue_free()
		return
	var _open:bool = is_open()
	label.text = "REJOIN HOST" if _open else status_text(Net.ghost_host_room)
	label.add_theme_color_override("font_color", OPEN_COLOR if _open else SHUT_COLOR)
	sprite.modulate = Color.WHITE if _open else Color(1, 1, 1, 0.45)
	if !_open:
		sprite.frame = 0

## What the shut portal says about where the host is.
static func status_text(host_room:String)->String:
	if host_room == NetPlayers.VICTORY_SCENE:
		return "HOST WON - HEADING HOME..."
	if host_room == NetPlayers.GAME_OVER_SCENE:
		return "HOST FELL - HEADING HOME..."
	return "HOST IS TRAVELLING..."

func _arm_if_clear()->void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var _local:Node2D = Net.players.local_body()
	_armed = _local == null || !get_overlapping_bodies().has(_local)

func _on_body_exited(body:Node2D)->void:
	if body == Net.players.local_body():
		_armed = true

func _on_body_entered(body:Node2D)->void:
	if body != Net.players.local_body() || !_armed || _used:
		return
	_try_rejoin()

## Into the host's game (NetPlayers follows it to the host's room).
func _try_rejoin()->bool:
	if !is_open():
		return false
	_used = true
	Net.return_from_ghost()
	return true

func _process(delta:float)->void:
	if !is_open():
		return
	_frame_left -= delta
	if _frame_left > 0.0:
		return
	_frame_left = FRAME_TIME
	sprite.frame = 1 + sprite.frame % (sprite.hframes - 1)
