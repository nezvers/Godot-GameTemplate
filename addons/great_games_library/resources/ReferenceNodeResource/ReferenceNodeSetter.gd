## Node to act as automatic reference assigner for ReferenceNodeResource.
class_name ReferenceNodeSetter
extends Node

## Node to be assigned to Reference resource
@export var reference_node:Node

## Reference resource that will be referencing a Node. If `reference_resource_path` is not empty it will overwrite resource.
@export var reference_resource:ReferenceNodeResource

## If not empty it will overwrite resource.
@export var reference_resource_path:String

## Initializes only if node is able to process in a tree
@export var process_only:bool = false

## Reference is removed when node exits tree
@export var until_tree_exit:bool = true

func _ready()->void:
	if process_only && !can_process():
		return
	
	if !reference_resource_path.is_empty():
		reference_resource = load(reference_resource_path)
	
	assert(reference_resource != null)
	
	reference_resource.set_reference(reference_node, until_tree_exit)
