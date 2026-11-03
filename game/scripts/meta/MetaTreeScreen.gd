## Meta-upgrade screen: the upgrade graph from upgrades.json, bought with boss crystals.
##
## Nodes are walked with the ui directions (neighbours picked by where they sit on
## the graph) and bought with ui_accept or a click. The view pans to keep the
## focused node centred; dragging the background pans it by hand.
## ui_cancel / pause goes back to the title.
extends Control

const TITLE_SCENE:String = "res://game/scenes/title.tscn"
## Neighbour search: how far off a direction (in degrees) a node may sit.
const NEIGHBOUR_CONE:float = 50.0
const PAN_TIME:float = 0.25
const OWNED_TEXT:Color = Color(0.55, 0.9, 0.6)
const SHORT_TEXT:Color = Color(1.0, 0.42, 0.42)
const COST_TEXT:Color = Color(1.0, 0.72, 0.94)
const LOCKED_TEXT:Color = Color(0.6, 0.58, 0.68)
const KEYSTONE_TEXT:Color = Color8(255, 214, 90)

@export var meta_upgrade_resource:MetaUpgradeResource
@export var boss_crystal_resource:ScoreResource
@export var action_resource:ActionResource
@export var buy_sound:SoundResource
@export var denied_sound:SoundResource
@export var back_sound:SoundResource

@export_group("Nodes")
## Clips the graph; its centre is where the focused node is brought.
@export var graph_view:Control
## Holds the node buttons, moved to pan.
@export var graph_content:Control
@export var graph_links:MetaGraphLinks
@export var crystal_label:Label
@export var progress_label:Label
@export var name_label:Label
@export var tag_label:Label
@export var text_label:Label
@export var state_label:Label
@export var back_button:Button
@export var reset_button:Button

## id -> MetaNodeButton
var buttons:Dictionary
var focused_id:String = MetaUpgrades.ROOT
var _pan_tween:Tween
var _dragging:bool
## Focus taken by hovering: show its info without panning under the mouse.
var _mouse_focus:bool
var _reset_armed:bool
var _leaving:bool

func _ready()->void:
	assert(meta_upgrade_resource != null)
	assert(boss_crystal_resource != null)
	meta_upgrade_resource.load_resource()
	boss_crystal_resource.load_resource()

	for _id:String in MetaUpgrades.nodes():
		var _button:MetaNodeButton = MetaNodeButton.new()
		_button.setup(_id)
		graph_content.add_child(_button)
		buttons[_id] = _button
		_button.pressed.connect(_buy.bind(_id))
		_button.focus_entered.connect(_on_focus.bind(_id))
		_button.mouse_entered.connect(_on_hover.bind(_button))
	_set_neighbours()
	graph_links.meta_upgrade_resource = meta_upgrade_resource
	graph_view.gui_input.connect(_on_graph_input)

	meta_upgrade_resource.updated.connect(_refresh)
	boss_crystal_resource.updated.connect(_refresh)
	back_button.pressed.connect(_back)
	reset_button.pressed.connect(_on_reset)
	_refresh()
	_start.call_deferred()

func _exit_tree()->void:
	meta_upgrade_resource.updated.disconnect(_refresh)
	boss_crystal_resource.updated.disconnect(_refresh)

## Once the layout has sizes: centre on the root and focus it.
func _start()->void:
	graph_content.position = _pan_target(focused_id)
	buttons[focused_id].grab_focus()

func _unhandled_input(event:InputEvent)->void:
	if event.is_action_released("ui_cancel") || (action_resource != null && event.is_action_released(action_resource.pause_action)):
		get_viewport().set_input_as_handled()
		_back()

func _back()->void:
	if _leaving:
		return
	_leaving = true
	if back_sound != null:
		back_sound.play_managed()
	Transition.change_scene(TITLE_SCENE)

func _buy(id:String)->void:
	var _button:MetaNodeButton = buttons[id]
	if meta_upgrade_resource.buy(id):
		_button.play_bought()
		if buy_sound != null:
			buy_sound.play_managed()
		return
	if meta_upgrade_resource.state(id) != MetaUpgradeResource.State.OWNED:
		_button.play_denied()
		if denied_sound != null:
			denied_sound.play_managed()

## First press asks, the second within 2s refunds every crystal spent.
func _on_reset()->void:
	if !_reset_armed:
		_reset_armed = true
		reset_button.text = "Sure?"
		get_tree().create_timer(2.0).timeout.connect(_disarm_reset)
		return
	_disarm_reset()
	meta_upgrade_resource.refund_all()
	for _id:String in buttons:
		buttons[_id].play_bought()

func _disarm_reset()->void:
	_reset_armed = false
	reset_button.text = "Reset"

func _refresh()->void:
	crystal_label.text = str(boss_crystal_resource.value)
	var _owned:int = 0
	for _id:String in buttons:
		var _state:MetaUpgradeResource.State = meta_upgrade_resource.state(_id)
		if _state == MetaUpgradeResource.State.OWNED:
			_owned += 1
		buttons[_id].refresh(_state, LootItems.can_afford(MetaUpgrades.cost(_id)))
	progress_label.text = "%d/%d" % [_owned, buttons.size()]
	reset_button.disabled = meta_upgrade_resource.owned.is_empty()
	graph_links.queue_redraw()
	_show_info(focused_id)

func _show_info(id:String)->void:
	var _node:Dictionary = MetaUpgrades.node(id)
	name_label.text = _node.get("title", id)
	var _keystone:bool = MetaUpgrades.is_keystone(id)
	name_label.modulate = KEYSTONE_TEXT if _keystone else Color.WHITE
	tag_label.visible = _keystone && id != MetaUpgrades.ROOT
	text_label.text = MetaUpgrades.describe(id)
	match meta_upgrade_resource.state(id):
		MetaUpgradeResource.State.OWNED:
			state_label.text = "Owned"
			state_label.modulate = OWNED_TEXT
		MetaUpgradeResource.State.AVAILABLE:
			var _cost:Array = MetaUpgrades.cost(id)
			var _affordable:bool = LootItems.can_afford(_cost)
			state_label.text = "Cost: %s%s" % [LootItems.describe(_cost), "" if _affordable else "  (not enough)"]
			state_label.modulate = COST_TEXT if _affordable else SHORT_TEXT
		MetaUpgradeResource.State.LOCKED:
			var _titles:PackedStringArray = []
			for _required:String in MetaUpgrades.requires(id):
				_titles.append(MetaUpgrades.node(_required).get("title", _required))
			state_label.text = "Requires %s" % " or ".join(_titles)
			state_label.modulate = LOCKED_TEXT

func _on_focus(id:String)->void:
	focused_id = id
	_show_info(id)
	if !_mouse_focus:
		_pan_to(id)

func _on_hover(button:MetaNodeButton)->void:
	if _dragging || button.has_focus():
		return
	_mouse_focus = true
	button.grab_focus()
	_mouse_focus = false

func _pan_target(id:String)->Vector2:
	return (graph_view.size * 0.5 - MetaUpgrades.position(id)).round()

func _pan_to(id:String)->void:
	if _pan_tween != null:
		_pan_tween.kill()
	_pan_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pan_tween.tween_property(graph_content, "position", _pan_target(id), PAN_TIME)

func _on_graph_input(event:InputEvent)->void:
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging && _pan_tween != null:
			_pan_tween.kill()
	elif event is InputEventMouseMotion && _dragging:
		graph_content.position = (graph_content.position + event.relative).round()

## For every node and direction: the nearest node inside a cone around that
## direction. Without one, focus stays put instead of jumping to the buttons.
func _set_neighbours()->void:
	var _directions:Dictionary = {
		SIDE_LEFT: Vector2.LEFT, SIDE_RIGHT: Vector2.RIGHT, SIDE_TOP: Vector2.UP, SIDE_BOTTOM: Vector2.DOWN,
	}
	for _id:String in buttons:
		var _button:MetaNodeButton = buttons[_id]
		var _from:Vector2 = MetaUpgrades.position(_id)
		for _side:Side in _directions:
			var _best:MetaNodeButton = _button
			var _best_score:float = INF
			for _other_id:String in buttons:
				if _other_id == _id:
					continue
				var _offset:Vector2 = MetaUpgrades.position(_other_id) - _from
				var _angle:float = rad_to_deg(absf(_offset.angle_to(_directions[_side])))
				if _angle > NEIGHBOUR_CONE:
					continue
				# Straight ahead wins over a closer node off to the side.
				var _score:float = _offset.length() * (1.0 + _angle / 45.0)
				if _score < _best_score:
					_best_score = _score
					_best = buttons[_other_id]
			_button.set_focus_neighbor(_side, _button.get_path_to(_best))
		_button.focus_next = _button.get_path_to(_button)
		_button.focus_previous = _button.get_path_to(_button)

## Focus walk for tests: the node reached from `id` going toward `side`.
func neighbour(id:String, side:Side)->String:
	var _button:MetaNodeButton = buttons[id]
	var _target:Node = _button.get_node(_button.get_focus_neighbor(side))
	return _target.id if _target is MetaNodeButton else id
