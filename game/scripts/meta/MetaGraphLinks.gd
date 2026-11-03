## Draws under the meta-upgrade nodes: a faint dot grid and the links from each
## node to the nodes it requires, coloured by how far along that link is.
class_name MetaGraphLinks
extends Control

const DOT:Color = Color(1, 1, 1, 0.12)
const LABEL:Color = Color(1, 1, 1, 0.22)
const LABEL_SIZE:int = 8
const OUTLINE:Color = Color8(24, 14, 30)
const LOCKED:Color = Color8(50, 48, 64)
const AVAILABLE:Color = Color8(130, 134, 152)
const OWNED:Color = Color8(255, 120, 220)
const OWNED_KEYSTONE:Color = Color8(255, 214, 90)
## Grid cells of dots around the outermost nodes.
const DOT_MARGIN:int = 2

var meta_upgrade_resource:MetaUpgradeResource

func _draw()->void:
	if meta_upgrade_resource == null:
		return
	_draw_dots()
	_draw_labels()
	var _nodes:Dictionary = MetaUpgrades.nodes()
	for _id:String in _nodes:
		for _required:String in MetaUpgrades.requires(_id):
			if _nodes.has(_required):
				_draw_link(_required, _id)

func _draw_link(from:String, to:String)->void:
	var _a:Vector2 = MetaUpgrades.position(from)
	var _b:Vector2 = MetaUpgrades.position(to)
	draw_line(_a, _b, OUTLINE, 4.0)
	draw_line(_a, _b, link_color(from, to), 2.0)

func link_color(from:String, to:String)->Color:
	var _meta:MetaUpgradeResource = meta_upgrade_resource
	if _meta.is_owned(from) && _meta.is_owned(to):
		return OWNED_KEYSTONE if MetaUpgrades.is_keystone(to) || (MetaUpgrades.is_keystone(from) && from != MetaUpgrades.ROOT) else OWNED
	if _meta.is_owned(from):
		return AVAILABLE
	return LOCKED

## Centred on their position.
func _draw_labels()->void:
	var _font:Font = get_theme_default_font()
	for _label:Dictionary in MetaUpgrades.labels():
		var _text:String = _label.get("text", "")
		var _pos:Array = _label.get("pos", [0, 0])
		var _size:Vector2 = _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
		var _at:Vector2 = Vector2(_pos[0], _pos[1]) * MetaUpgrades.grid() + Vector2(-_size.x * 0.5, _font.get_ascent(LABEL_SIZE) * 0.5)
		draw_string(_font, _at.round(), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL)

func _draw_dots()->void:
	var _grid:float = MetaUpgrades.grid()
	var _min:Vector2i = Vector2i.ZERO
	var _max:Vector2i = Vector2i.ZERO
	for _id:String in MetaUpgrades.nodes():
		var _cell:Vector2i = Vector2i((MetaUpgrades.position(_id) / _grid).round())
		_min = _min.min(_cell)
		_max = _max.max(_cell)
	# Dots sit halfway between cells so they never peek out from behind a frame.
	for _y:int in range(_min.y - DOT_MARGIN, _max.y + DOT_MARGIN):
		for _x:int in range(_min.x - DOT_MARGIN, _max.x + DOT_MARGIN):
			draw_rect(Rect2((Vector2(_x, _y) + Vector2.ONE * 0.5) * _grid, Vector2.ONE), DOT)
