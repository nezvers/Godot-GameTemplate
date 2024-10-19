class_name PauseComponent
extends Node

## BoolResource that is used fot pausing game's state
@export var pause_value_resource:BoolResource
## List of nodes that will be shown during game's pause
@export var pause_show_list:Array[Node]
## List of nodes that will be hidden when game is paused
@export var pause_hide_list:Array[Node]
## List of nodes which process_mode will be manipulated
@export var paused_nodes:Array[Node]
## This state will be used for paused nodes when game is paused
@export var paused_state:Node.ProcessMode
## This state will be used for paused nodes when game is unpaused
@export var not_paused_state:Node.ProcessMode

func _ready()->void:
	pause_value_resource.updated.connect(pause_changed)
	pause_changed()

func pause_changed()->void:
	var _is_paused:bool = pause_value_resource.value
	for node:Node in pause_show_list:
		node.visible = _is_paused
	for node:Node in pause_hide_list:
		node.visible = !_is_paused
	for node:Node in paused_nodes:
		node.process_mode = paused_state if _is_paused else not_paused_state
