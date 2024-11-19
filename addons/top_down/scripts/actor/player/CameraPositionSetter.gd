class_name CameraPositionSetter
extends Node

@export var camera_reference:ReferenceNodeResource
@export var position_resource:Vector2Resource
@export var target_node:Node2D

func _ready()->void:
	assert(camera_reference != null)
	camera_reference.listen(self, on_camera_reference)
	
	# Same player will be moved between scenes
	tree_entered.connect(on_camera_reference)

func on_camera_reference()->void:
	if !is_inside_tree():
		return
	if camera_reference.node == null:
		return
	position_resource.set_value(target_node.global_position)
	camera_reference.node.set_target_position(position_resource)

func _physics_process(delta: float)->void:
	position_resource.set_value(target_node.global_position)
