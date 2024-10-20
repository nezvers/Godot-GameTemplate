class_name ItemDrop
extends Node

@export var root_node:Node2D
@export var drop_parent_reference:ReferenceNodeResource
@export var resource_node:ResourceNode
@export var asset_list:StringArrayResource
@export var drop_chance:float = 0.1

func _ready()->void:
	assert(drop_parent_reference != null)
	
	var _health_resource:HealthResource = resource_node.get_resource("health")
	assert(_health_resource != null)
	_health_resource.dead.connect(on_death)

func on_death()->void:
	if asset_list.value.is_empty():
		return
	if randf() > 0.1:
		return
	var drop_position:Vector2 = root_node.global_position
	var path:String = asset_list.value.pick_random()
	var scene:PackedScene = load(path)
	var inst:Node2D = scene.instantiate()
	inst.global_position = drop_position
	drop_parent_reference.node.add_child.call_deferred(inst)
