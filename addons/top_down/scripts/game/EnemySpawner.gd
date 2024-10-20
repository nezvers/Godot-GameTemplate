class_name EnemySpawner
extends Node

## Notify that new enemy spawned and sends a reference of it.
## In case something post-processing is needed.
signal object_instantiated(inst:Node2D)

@export var enabled:bool = true
## Spawned instance will be positioned relative to this node
## TODO: Probably choosing should be done by child node function
@export var spawn_positions_list:Array[Node2D]
## Spawned instance will be put under this node
@export var spawn_parent_reference:ReferenceNodeResource
## Spawning will create a new instance of this scene
## TODO: Expose list of available objects and child function does the choice & instantiate
@export var object_scene:PackedScene

func set_enabled(value:bool)->void:
	enabled = value

func spawn_scene()->void:
	if !enabled:
		return
	assert(spawn_parent_reference != null)
	assert(spawn_parent_reference.node != null)
	assert(object_scene != null)
	assert(!spawn_positions_list.is_empty())
	
	## BUG: If multiple enemies spawned at the same spot they are yeeted out of the map
	## TODO: Move instantiating to child function node
	var inst:Node2D = object_scene.instantiate()
	
	var spawn_position_node:Node2D = spawn_positions_list.pick_random()
	inst.global_position = spawn_position_node.global_position
	spawn_parent_reference.node.add_child(inst)
	object_instantiated.emit(inst)
