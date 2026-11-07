## Home base co-op terminal: opens the Host / Join dialog. The screen lights up
## while a session is open.
class_name CommsTerminal
extends Interactable

const DIALOG_SCRIPT:String = "res://game/scripts/ui/CoopDialog.gd"

@export var sprite:Sprite2D

var _dialog:Node

func _ready()->void:
	super._ready()
	Net.state_changed.connect(_refresh)
	_refresh()

func _refresh()->void:
	if sprite != null:
		sprite.frame = 1 if Net.is_online() else 0

func _can_use()->bool:
	return _dialog == null

func _use()->void:
	busy = true
	var _layer:CanvasLayer = CanvasLayer.new()
	# above the HUD, below Transition (5)
	_layer.layer = 4
	_layer.name = "CoopDialogLayer"
	_dialog = (load(DIALOG_SCRIPT) as GDScript).new()
	_layer.add_child(_dialog)
	get_tree().root.add_child(_layer)
	_set_player_input(false)
	_dialog.tree_exited.connect(func ()->void:
		_dialog = null
		busy = false
		if is_instance_valid(_layer):
			_layer.queue_free()
		if is_inside_tree():
			_set_player_input(true), CONNECT_ONE_SHOT)
	tree_exiting.connect(func ()->void:
		if is_instance_valid(_layer):
			_layer.queue_free(), CONNECT_ONE_SHOT)

## No walking or shooting while typing an address.
func _set_player_input(enabled:bool)->void:
	var _player:Node = player_reference.node
	if _player == null:
		return
	var _input:PlayerInput = _player.get_node_or_null("PlayerInput") as PlayerInput
	if _input == null:
		return
	_input.set_enabled(enabled)
	if !enabled && _input.input_resource != null:
		_input.input_resource.set_axis(Vector2.ZERO)
		_input.input_resource.set_action(false)
		_input.input_resource.set_action_2(false)

func _prompt_text()->String:
	return "Co-op (%d)" % RunSession.players.count() if Net.is_online() else "Co-op"
