class_name ProcessingComponent
extends Node

## BoolResource that is used fot pausing game's state
@export var bool_resource:BoolResource

## List of nodes which process_mode will be manipulated
@export var paused_nodes:Array[Node]

## List of nodes which process_mode will be reverse state
@export var unpaused_nodes:Array[Node]

## This state will be used for paused nodes when game is paused
@export var paused_state:Node.ProcessMode

## This state will be used for paused nodes when game is unpaused
@export var not_paused_state:Node.ProcessMode

## Co-op: other players keep playing, so the world isn't frozen while online
## (NetPlayers stops just the local player instead).
@export var keep_running_online:bool

func _ready()->void:
	bool_resource.updated.connect(pause_changed)
	pause_changed()

func pause_changed()->void:
	var _is_paused:bool = bool_resource.value
	if keep_running_online && Net.is_online():
		_is_paused = false
	for node:Node in paused_nodes:
		node.process_mode = paused_state if _is_paused else not_paused_state
	for node:Node in unpaused_nodes:
		node.process_mode = not_paused_state if _is_paused else paused_state
