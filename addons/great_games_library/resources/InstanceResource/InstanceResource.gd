class_name InstanceResource
extends SaveableResource

signal updated

## Using file path to a scene no not cause cyclic reference when including in scenes.
## Scene file will be loaded when instancing scene for the first time
@export var scene_path:String
## Reference to a node that will be used as a parent.
@export var parent_reference_resource:ReferenceNodeResource

## After first instance crewation a scene file is cached
var scene:PackedScene
## Collect references of all active instances
var instance_list:Array[Node]

func create_instance()->Node:
	if scene == null:
		scene = load(scene_path)
		assert(scene != null)
	var _inst:Node = scene.instantiate()
	instance_list.append(_inst)
	_inst.tree_exiting.connect(erase.bind(_inst))
	updated.emit()
	return _inst

## Pass config_callback to configure instance before it is added the scene tree
func instance(config_callback:Callable = Callable())->Node:
	assert(parent_reference_resource != null)
	assert(parent_reference_resource.node != null)
	var _inst:Node = create_instance()
	if config_callback.is_valid():
		config_callback.call(_inst)
	parent_reference_resource.node.add_child(_inst)
	return _inst

## Remove from active instance list
func erase(node:Node)->void:
	instance_list.erase(node)
	updated.emit()
