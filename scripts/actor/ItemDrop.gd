class_name ItemDrop
extends Node

@export var root_node:Node2D
@export var asset_list:StringArrayResource
@export var drop_chance:float = 0.1

func _ready()->void:
	root_node.tree_exiting.connect(on_exiting)

func on_exiting()->void:
	if asset_list.value.is_empty():
		return
	if randf() > 0.1:
		return
	var parent:Node = root_node.get_parent()
	var drop_position:Vector2 = root_node.global_position
	var path:String = asset_list.value.pick_random()
	var scene:PackedScene = load(path)
	var inst:Node2D = scene.instantiate()
	inst.global_position = drop_position
	parent.add_child.call_deferred(inst)
