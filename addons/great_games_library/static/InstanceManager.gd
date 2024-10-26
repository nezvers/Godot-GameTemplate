class_name InstanceManager
extends Node

static func instance(scene:PackedScene, parent_reference:ReferenceNodeResource)->Node:
	assert(scene != null)
	assert(parent_reference != null)
	assert(parent_reference.node != null)
	var inst:Node = scene.instantiate()
	parent_reference.node.add_child(inst)
	return inst

static func instance_2d(scene:PackedScene, parent_reference:ReferenceNodeResource, position:Vector2 = Vector2.ZERO)->Node:
	assert(scene != null)
	assert(parent_reference != null)
	assert(parent_reference.node != null)
	var inst:Node = scene.instantiate()
	inst.global_position = position
	parent_reference.node.add_child(inst)
	return inst

static func instance_3d(scene:PackedScene, parent_reference:ReferenceNodeResource, position:Vector3 = Vector3.ZERO)->Node:
	assert(scene != null)
	assert(parent_reference != null)
	assert(parent_reference.node != null)
	var inst:Node3D = scene.instantiate()
	inst.global_position = position
	parent_reference.node.add_child(inst)
	return inst
