class_name InstanceResource
extends Resource

signal updated

## Using file path to a scene no not cause cyclic reference when including in scenes.
## Scene file will be loaded when instancing scene for the first time
@export var scene_path:String
## Reference to a node that will be used as a parent.
@export var parent_reference_resource:ReferenceNodeResource

## After first instance crewation a scene file is cached
var scene:PackedScene
## Collect references of all active instances
var active_list:Array[Node]
## Inactive scenes with a PoolNode are put in the list, to pull out when a new one is needed, instead of instancing every time.
var pool_list:Array[Node]

func _create_instance()->Node:
	if scene == null:
		scene = load(scene_path)
		assert(scene != null)
	
	# Use pooled instances first
	if !pool_list.is_empty():
		var _node:Node = pool_list.pop_back()
		active_list.append(_node)
		updated.emit()
		return _node
	
	var _node:Node = scene.instantiate()
	active_list.append(_node)
	
	
	if _node.has_node("PoolNode"):
		var _pool_node:PoolNode = _node.get_node("PoolNode")
		_pool_node.pool_requested.connect(_return_to_pool.bind(_node))
	else:
		_node.tree_exiting.connect(_erase.bind(_node))
	
	updated.emit()
	return _node

## Pass a config_callback to configure instance before it is added the scene tree
func instance(config_callback:Callable = Callable())->Node:
	assert(parent_reference_resource != null)
	assert(parent_reference_resource.node != null)
	var _node:Node = _create_instance()
	if config_callback.is_valid():
		config_callback.call(_node)
	parent_reference_resource.node.add_child(_node)
	return _node

## Remove from active instance list
func _erase(node:Node)->void:
	active_list.erase(node)
	updated.emit()

func _return_to_pool(node:Node)->void:
	active_list.erase(node)
	pool_list.append(node)
	parent_reference_resource.node.remove_child.call_deferred(node)
