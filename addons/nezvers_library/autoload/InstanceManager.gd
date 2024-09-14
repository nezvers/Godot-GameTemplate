extends Node

func instance(scene:PackedScene, parent_reference:ReferenceNodeResource, position:Vector2 = Vector2.ZERO)->void:
	assert(scene != null)
	assert(parent_reference != null)
	assert(parent_reference.node != null)
	var inst:Node = scene.instantiate()
	if inst is CanvasItem || inst is Node3D:
		inst.global_position = position
	parent_reference.node.add_child(inst)
