## Co-op HUD, docked to the right edge: one card per teammate (not the local
## player, whose HP and weapons are on the left) with name, HP bar and the
## weapon in hand. Hidden offline and while alone in the session.
##
## Fed by RunSession.players: rows come and go with the roster, and each row
## refreshes on its PlayerState's hp_changed / net_updated.
class_name PartyPanel
extends VBoxContainer

const WIDTH:float = 92.0
const FONT_SIZE:int = 7
## One colour per slot, shared with anything else that marks players.
const SLOT_COLORS:Array[Color] = [
	Color("f2c14e"), Color("5fb3f9"), Color("f25f5c"), Color("7bd389"),
	Color("c792ea"), Color("ff9f43"), Color("4ecdc4"), Color("e0e0e0"),
]
const HP_COLOR:Color = Color("62c370")
const HP_LOW_COLOR:Color = Color("e5534b")
const DOWNED_COLOR:Color = Color("8a8a8a")
const AWAY_ALPHA:float = 0.55

## slot -> {"root", "name", "bar", "hp", "icon", "weapon", "state"}
var rows:Dictionary = {}

func _ready()->void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -WIDTH - 3.0
	offset_right = -3.0
	offset_top = 4.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	RunSession.players.player_added.connect(_on_roster_change.unbind(1))
	RunSession.players.player_removed.connect(_on_roster_change.unbind(1))
	Net.roster_changed.connect(_on_roster_change)
	Net.state_changed.connect(_on_roster_change)
	_rebuild()

func _exit_tree()->void:
	for _slot:int in rows.keys():
		_disconnect_row(rows[_slot])

func _on_roster_change()->void:
	_rebuild.call_deferred()

func _rebuild()->void:
	if !is_inside_tree():
		return
	var _wanted:Dictionary = {}
	if Net.is_online() && !Net.is_ghost():
		for _state:PlayerState in RunSession.players.all():
			if !_state.is_local && !_state.hidden:
				_wanted[_state.slot] = _state
	for _slot:int in rows.keys():
		if !_wanted.has(_slot) || rows[_slot].state != _wanted[_slot]:
			_disconnect_row(rows[_slot])
			(rows[_slot].root as Node).queue_free()
			rows.erase(_slot)
	var _slots:Array = _wanted.keys()
	_slots.sort()
	for _slot:int in _slots:
		if !rows.has(_slot):
			rows[_slot] = _make_row(_wanted[_slot])
			add_child(rows[_slot].root)
		move_child(rows[_slot].root, -1)
		_refresh(_slot)
	visible = !rows.is_empty()

func _make_row(state:PlayerState)->Dictionary:
	var _card:PanelContainer = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size.x = WIDTH
	var _style:StyleBoxFlat = StyleBoxFlat.new()
	_style.bg_color = Color(0.05, 0.06, 0.09, 0.72)
	_style.border_color = SLOT_COLORS[state.slot % SLOT_COLORS.size()]
	_style.border_width_left = 2
	_style.set_corner_radius_all(2)
	_style.content_margin_left = 4
	_style.content_margin_right = 3
	_style.content_margin_top = 2
	_style.content_margin_bottom = 2
	_card.add_theme_stylebox_override("panel", _style)
	var _box:VBoxContainer = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 1)
	_card.add_child(_box)

	var _name:Label = _label(state.display_name)
	_name.add_theme_color_override("font_color", SLOT_COLORS[state.slot % SLOT_COLORS.size()])
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_box.add_child(_name)

	var _hp_line:HBoxContainer = HBoxContainer.new()
	_hp_line.add_theme_constant_override("separation", 3)
	var _bar:ProgressBar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 4)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var _back:StyleBoxFlat = StyleBoxFlat.new()
	_back.bg_color = Color(0, 0, 0, 0.6)
	_bar.add_theme_stylebox_override("background", _back)
	var _fill:StyleBoxFlat = StyleBoxFlat.new()
	_fill.bg_color = HP_COLOR
	_bar.add_theme_stylebox_override("fill", _fill)
	_hp_line.add_child(_bar)
	var _hp:Label = _label("")
	_hp.custom_minimum_size.x = 30
	_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_line.add_child(_hp)
	_box.add_child(_hp_line)

	var _weapon_line:HBoxContainer = HBoxContainer.new()
	_weapon_line.add_theme_constant_override("separation", 2)
	var _icon:TextureRect = TextureRect.new()
	_icon.custom_minimum_size = Vector2(12, 12)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_line.add_child(_icon)
	var _weapon:Label = _label("")
	_weapon.clip_text = true
	_weapon.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_weapon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_line.add_child(_weapon)
	_box.add_child(_weapon_line)

	var _row:Dictionary = {"root": _card, "name": _name, "bar": _bar, "fill": _fill, "hp": _hp, "icon": _icon, "weapon": _weapon, "state": state}
	var _refresh_call:Callable = _refresh.bind(state.slot)
	_row["callback"] = _refresh_call
	state.health.hp_changed.connect(_refresh_call)
	state.health.max_hp_changed.connect(_refresh_call)
	state.net_updated.connect(_refresh_call)
	return _row

func _disconnect_row(row:Dictionary)->void:
	var _state:PlayerState = row.state
	var _call:Callable = row.callback
	for _signal:Signal in [_state.health.hp_changed, _state.health.max_hp_changed, _state.net_updated]:
		if _signal.is_connected(_call):
			_signal.disconnect(_call)

func _label(text:String)->Label:
	var _label_node:Label = Label.new()
	_label_node.text = text
	_label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_node.add_theme_font_size_override("font_size", FONT_SIZE)
	_label_node.add_theme_color_override("font_outline_color", Color.BLACK)
	_label_node.add_theme_constant_override("outline_size", 1)
	return _label_node

func _refresh(slot:int)->void:
	if !rows.has(slot):
		return
	var _row:Dictionary = rows[slot]
	var _state:PlayerState = _row.state
	var _away:bool = _state.ghost || _state.room_scene.is_empty() || _state.room_scene != _current_room()
	var _name:String = _state.display_name
	if _state.ghost:
		_name += "  (at home)"
	elif _state.waiting:
		_name += "  WAITING"
	elif _state.downed:
		_name += "  REVIVING %d%%" % roundi(_state.revive_progress * 100.0) if _state.revive_progress > 0.0 else "  DOWN"
	elif _away:
		_name += "  (away)"
	(_row.name as Label).text = _name
	var _max:float = maxf(_state.health.max_hp, 1.0)
	var _bar:ProgressBar = _row.bar
	_bar.max_value = _max
	_bar.value = clampf(_state.health.hp, 0.0, _max)
	var _ratio:float = _state.health.hp / _max
	(_row.fill as StyleBoxFlat).bg_color = DOWNED_COLOR if _state.downed else (HP_LOW_COLOR if _ratio <= 0.3 else HP_COLOR)
	(_row.hp as Label).text = "%d/%d" % [ceili(_state.health.hp), ceili(_max)]
	var _item:ItemResource = _state.active_weapon()
	(_row.icon as TextureRect).texture = _item.icon if _item != null else null
	(_row.icon as TextureRect).visible = _item != null
	(_row.weapon as Label).text = _item.resource_name if _item != null else "Fists"
	(_row.root as Control).modulate.a = AWAY_ALPHA if _away || _state.downed || _state.waiting else 1.0

func _current_room()->String:
	var _scene:Node = get_tree().current_scene
	return _scene.scene_file_path if _scene != null else ""
