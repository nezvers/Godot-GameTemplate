## Co-op guest's choice when a run ends for it (victory screen) or when it steps
## back into the door while waiting for a fight to end (WaitingAtDoor):
##   - Stay with the host / Wait for the host: stay in the session (after a
##     victory the host's next scene, its home base or a mission, takes us along).
##   - Go to my home base, with "I will return (show my ghost)": checked, the
##     seat is kept (Net.go_ghost) and a rejoin portal waits at home; unchecked,
##     a plain leave.
## Built in code on its own CanvasLayer, game_gui_theme at a small size.
class_name GuestLeaveMenu
extends Control

enum Context {VICTORY, DOOR}

const THEME_PATH:String = "res://addons/top_down/resources/theme/game_gui_theme.theme"
const HOME_SCENE:String = "res://game/scenes/room_H00.tscn"
const FONT_SIZE:int = 8

## Stay with the host / Wait for the host was picked (the menu closes itself).
signal stay_chosen
## Going home; ghost = "I will return" was checked.
signal home_chosen(ghost:bool)

var context:Context
var ghost_check:CheckBox
var stay_button:Button
var home_button:Button
var status:Label
var _layer:CanvasLayer
var _player_input_off:Node

## Opens the menu over the game; `owner_node` only ties its life to a node.
static func open(owner_node:Node, for_context:Context)->GuestLeaveMenu:
	var _menu:GuestLeaveMenu = GuestLeaveMenu.new()
	_menu.context = for_context
	var _layer_node:CanvasLayer = CanvasLayer.new()
	_layer_node.layer = 4
	_layer_node.name = "GuestLeaveMenuLayer"
	_menu._layer = _layer_node
	_layer_node.add_child(_menu)
	owner_node.get_tree().root.add_child(_layer_node)
	owner_node.tree_exiting.connect(_menu.close, CONNECT_ONE_SHOT)
	return _menu

func _ready()->void:
	theme = _small_theme()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build()
	_freeze_player(true)
	stay_button.grab_focus.call_deferred()

func _build()->void:
	var _dim:ColorRect = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_dim)
	var _center:CenterContainer = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_center)
	var _panel:PanelContainer = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(200, 0)
	_center.add_child(_panel)
	var _margin:MarginContainer = MarginContainer.new()
	for _side:String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + _side, 6)
	_panel.add_child(_margin)
	var _box:VBoxContainer = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 5)
	_margin.add_child(_box)

	var _title:Label = Label.new()
	_title.text = "Run complete" if context == Context.VICTORY else "Leave the host's game?"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_title)

	stay_button = Button.new()
	stay_button.text = "Stay with the host" if context == Context.VICTORY else "Wait for the host"
	stay_button.pressed.connect(_on_stay)
	_box.add_child(stay_button)

	home_button = Button.new()
	home_button.text = "Go to my home base"
	home_button.pressed.connect(_on_home)
	_box.add_child(home_button)

	ghost_check = CheckBox.new()
	ghost_check.text = "I will return (leave my ghost)"
	ghost_check.button_pressed = true
	_box.add_child(ghost_check)

	status = Label.new()
	status.text = ""
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(status)

## The game GUI theme at the small menu size (shared with ConfirmPrompt).
static func _small_theme()->Theme:
	var _theme:Theme = (load(THEME_PATH) as Theme).duplicate()
	_theme.default_font_size = FONT_SIZE
	for _type:StringName in [&"Label", &"Button", &"CheckBox"]:
		_theme.set_font_size(&"font_size", _type, FONT_SIZE)
	return _theme

func _on_stay()->void:
	stay_chosen.emit()
	if context == Context.VICTORY:
		# the menu stays as a note; the host's next room takes us along
		stay_button.disabled = true
		home_button.disabled = true
		ghost_check.disabled = true
		status.text = "Waiting for the host to pick the home base or the next mission..."
		return
	close()

func _on_home()->void:
	go_home(ghost_check.button_pressed)

## Off to our own home base: as a ghost (seat kept, the rejoin portal waits) or
## leaving the session.
func go_home(ghost:bool)->void:
	home_chosen.emit(ghost)
	if Net.is_guest():
		if ghost:
			# leaving mid-run: the host keeps our run state for our return
			Net.go_ghost(context == Context.DOOR)
		else:
			Net.players.leaving_by_choice = true
			Net.leave()
	close()
	Transition.change_scene(HOME_SCENE)

func close()->void:
	if is_queued_for_deletion():
		return
	_freeze_player(false)
	if is_instance_valid(_layer):
		_layer.queue_free()
	else:
		queue_free()

## No walking or shooting while the menu is up.
func _freeze_player(frozen:bool)->void:
	var _body:Node2D = Net.players.local_body() if Net.players != null else null
	var _input:Node = _body.get_node_or_null("PlayerInput") if _body != null else null
	if _input == null:
		return
	_input.set_enabled(!frozen)
	if frozen:
		var _move:InputResource = (_body.get_node("ResourceNode") as ResourceNode).get_resource("input")
		_move.set_axis(Vector2.ZERO)
		_move.set_action(false)

## Escape picks the safe option: stay.
func _input(event:InputEvent)->void:
	if event.is_action("ui_cancel") || event.is_action(&"pause"):
		get_viewport().set_input_as_handled()
		if event.is_released() && !stay_button.disabled:
			_on_stay()
