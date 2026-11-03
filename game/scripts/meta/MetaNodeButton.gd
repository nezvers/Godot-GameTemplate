## One node of the meta-upgrade graph: its frame (normal strip, or the golden one
## for keystones; one frame per state), its icon and the focus cursor.
class_name MetaNodeButton
extends TextureButton

const NORMAL_FRAMES:Texture2D = preload("res://addons/top_down/assets/images/gui/meta_frame_normal_20x20_strip3.png")
const GOLDEN_FRAMES:Texture2D = preload("res://addons/top_down/assets/images/gui/meta_frame_golden_28x28_strip3.png")
const ICONS:Texture2D = preload("res://addons/top_down/assets/images/gui/meta_icons_12x12_strip10.png")
const CURSOR:Texture2D = preload("res://addons/top_down/assets/images/gui/meta_cursor_16x16.png")
const ICON_SIZE:int = 12
## Cursor brackets stand this far outside the frame.
const CURSOR_GAP:int = 3
const LOCKED_ICON:Color = Color(0.28, 0.26, 0.34)
const PULSE:Color = Color(1.45, 1.45, 1.45)
const FLASH:Color = Color(3.0, 3.0, 3.0)

var id:String
var keystone:bool
var _frame:AtlasTexture
var _icon:TextureRect
var _cursor:NinePatchRect
var _pulse_tween:Tween
var _cursor_tween:Tween
var _punch_tween:Tween

func setup(node_id:String)->void:
	id = node_id
	name = node_id
	keystone = MetaUpgrades.is_keystone(id)
	var _sheet:Texture2D = GOLDEN_FRAMES if keystone else NORMAL_FRAMES
	var _side:int = _sheet.get_height()
	_frame = AtlasTexture.new()
	_frame.atlas = _sheet
	_frame.region = Rect2(0, 0, _side, _side)
	texture_normal = _frame
	size = Vector2(_side, _side)
	position = MetaUpgrades.position(id) - size * 0.5
	pivot_offset = size * 0.5
	focus_mode = Control.FOCUS_ALL

	var _icon_texture:AtlasTexture = AtlasTexture.new()
	_icon_texture.atlas = ICONS
	_icon_texture.region = Rect2(MetaUpgrades.icon_index(id) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	_icon = TextureRect.new()
	_icon.texture = _icon_texture
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = Vector2.ONE * (_side - ICON_SIZE) / 2
	add_child(_icon)

	_cursor = NinePatchRect.new()
	_cursor.texture = CURSOR
	for _margin:Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_cursor.set_patch_margin(_margin, 6)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	add_child(_cursor)
	_place_cursor(CURSOR_GAP)

	focus_entered.connect(_set_focused.bind(true))
	focus_exited.connect(_set_focused.bind(false))

## Frame by state, dark icon while locked, a slow pulse while it can be bought.
func refresh(state:MetaUpgradeResource.State, affordable:bool)->void:
	_frame.region.position.x = int(state) * _frame.region.size.x
	_icon.modulate = LOCKED_ICON if state == MetaUpgradeResource.State.LOCKED else Color.WHITE
	var _pulse:bool = state == MetaUpgradeResource.State.AVAILABLE && affordable
	if _pulse == (_pulse_tween != null):
		return
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		self_modulate = Color.WHITE
	if _pulse:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(self, "self_modulate", PULSE, 0.6).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(self, "self_modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)

## Scale punch and a white flash.
func play_bought()->void:
	_restart_punch()
	scale = Vector2.ONE * 1.4
	modulate = FLASH
	_punch_tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.3)

## Shakes sideways: locked or too expensive.
func play_denied()->void:
	_restart_punch()
	var _x:float = MetaUpgrades.position(id).x - size.x * 0.5
	for _offset:float in [3.0, -3.0, 2.0, -1.0, 0.0]:
		_punch_tween.tween_property(self, "position:x", _x + _offset, 0.04)

func _restart_punch()->void:
	if _punch_tween != null:
		_punch_tween.kill()
	position = MetaUpgrades.position(id) - size * 0.5
	_punch_tween = create_tween()

func _set_focused(value:bool)->void:
	_cursor.visible = value
	if _cursor_tween != null:
		_cursor_tween.kill()
		_cursor_tween = null
	_place_cursor(CURSOR_GAP)
	if !value:
		return
	# Brackets breathe one pixel in and out.
	_cursor_tween = create_tween().set_loops()
	_cursor_tween.tween_callback(_place_cursor.bind(CURSOR_GAP + 1)).set_delay(0.35)
	_cursor_tween.tween_callback(_place_cursor.bind(CURSOR_GAP)).set_delay(0.35)

func _place_cursor(gap:int)->void:
	_cursor.position = -Vector2.ONE * gap
	_cursor.size = size + Vector2.ONE * gap * 2
