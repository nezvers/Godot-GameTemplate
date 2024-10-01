class_name PauseComponent
extends Node

@export var pause_value_resource:BoolResource
@export var pause_show_list:Array[Node]
@export var pause_hide_list:Array[Node]
@export var paused_state:Node.ProcessMode
@export var not_paused_state:Node.ProcessMode
@export var paused_nodes:Array[Node]

func _ready()->void:
	pause_value_resource.updated.connect(pause_changed)
	pause_changed()

func pause_changed()->void:
	var is_paused:bool = pause_value_resource.value
	for node:Node in pause_show_list:
		node.visible = is_paused
	for node:Node in pause_hide_list:
		node.visible = !is_paused
	for node:Node in paused_nodes:
		node.process_mode = paused_state if is_paused else not_paused_state
