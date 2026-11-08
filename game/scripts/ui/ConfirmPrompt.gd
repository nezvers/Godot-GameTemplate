## A small yes/no panel over the game, built in code like GuestLeaveMenu (its
## small theme, its own CanvasLayer). Escape picks "no".
class_name ConfirmPrompt
extends Control

signal confirmed
signal cancelled

var message:String
var yes_text:String
var no_text:String
var yes_button:Button
var no_button:Button
var _layer:CanvasLayer

## Opens over `owner_node`'s tree; it goes away with that node.
static func open(owner_node:Node, text:String, yes:String = "Yes", no:String = "No")->ConfirmPrompt:
	var _prompt:ConfirmPrompt = ConfirmPrompt.new()
	_prompt.message = text
	_prompt.yes_text = yes
	_prompt.no_text = no
	var _layer_node:CanvasLayer = CanvasLayer.new()
	_layer_node.layer = 5
	_layer_node.name = "ConfirmPromptLayer"
	_prompt._layer = _layer_node
	_layer_node.add_child(_prompt)
	owner_node.get_tree().root.add_child(_layer_node)
	owner_node.tree_exiting.connect(_prompt.close, CONNECT_ONE_SHOT)
	return _prompt

func _ready()->void:
	theme = GuestLeaveMenu._small_theme()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
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
	var _label:Label = Label.new()
	_label.text = message
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_label)
	no_button = Button.new()
	no_button.text = no_text
	no_button.pressed.connect(_on_no)
	_box.add_child(no_button)
	yes_button = Button.new()
	yes_button.text = yes_text
	yes_button.pressed.connect(_on_yes)
	_box.add_child(yes_button)
	no_button.grab_focus.call_deferred()

func _on_yes()->void:
	confirmed.emit()
	close()

func _on_no()->void:
	cancelled.emit()
	close()

func close()->void:
	if is_queued_for_deletion():
		return
	if is_instance_valid(_layer):
		_layer.queue_free()
	else:
		queue_free()

func _input(event:InputEvent)->void:
	if event.is_action("ui_cancel") || event.is_action(&"pause"):
		get_viewport().set_input_as_handled()
		if event.is_released():
			_on_no()
