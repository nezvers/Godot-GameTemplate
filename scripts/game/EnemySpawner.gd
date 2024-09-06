class_name EnemySpawner
extends Node

## Notify that new enemy spawned and sends a reference of it
signal object_instantiated(inst:Node2D)

@export var enabled:bool = true
## Spawned instance will be positioned relative to this node
@export var spawn_position_node:Node2D
## Spawned instance will be put under this node
@export var spawn_parent:Node2D
## Used for random distance
@export var radius_min:float
## Used for random distance
@export var radius_max:float
## Spawning will create a new instance of this scene
@export var object_scene:PackedScene
## Used to fake angled perspective
@export var axis_multiplication: = Vector2.ONE

func set_enabled(value:bool)->void:
	enabled = value
	set_process(enabled)

func spawn_scene()->void:
	if !enabled:
		return
	if spawn_parent == null:
		return
	if spawn_position_node == null:
		return
	if object_scene == null:
		return
	
	var rnd_angle:float = TAU * randf()
	var rnd_distance:float = lerp(radius_min, radius_max, randf())
	var spawn_offset:Vector2 = rnd_distance * Vector2.RIGHT.rotated(rnd_angle)
	
	var inst:Node2D = object_scene.instantiate()
	inst.global_position = spawn_position_node.global_position + spawn_offset * axis_multiplication
	spawn_parent.add_child(inst)
	object_instantiated.emit(inst)

