class_name VisibilityComponent
extends Node

## BoolResource that is used fot pausing game's state
@export var bool_resource:BoolResource

## List of nodes that will be shown during game's pause
@export var show_list:Array[Node]

## List of nodes that will be hidden when game is paused
@export var hide_list:Array[Node]

func _ready()->void:
	bool_resource.updated.connect(value_changed)
	value_changed()

func value_changed()->void:
	for node:Node in show_list:
		node.visible = bool_resource.value
	for node:Node in hide_list:
		node.visible = !bool_resource.value
