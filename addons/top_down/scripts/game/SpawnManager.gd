extends Node

@export var enemy_spawner:EnemySpawner
@export var target_count:int = 3

var active_count:int

func _ready()->void:
	enemy_spawner.object_instantiated.connect(object_instantiated)

func object_instantiated(inst:Node2D)->void:
	active_count += 1
	# TODO: check if killed not just removed from scene (restart or room change also removes from tree)
	# Maybe use Int value resource for kill count
	inst.tree_exiting.connect(add_active.bind(-1))

func add_active(value:int)->void:
	active_count += value

func _process(_delta:float)->void:
	if active_count >= target_count:
		return
	enemy_spawner.spawn_scene()
