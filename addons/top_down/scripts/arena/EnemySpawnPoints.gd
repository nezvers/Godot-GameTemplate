@tool
## Container for an arena's SpawnPoint markers. Adds an editor button to create
## new SpawnPoint children so they no longer have to be made by hand. Created
## points are stamped with default_section and saved into the scene.
class_name EnemySpawnPoints
extends Node2D

const SPAWN_POINT_SCRIPT:Script = preload("res://addons/top_down/scripts/arena/SpawnPoint.gd")

## Tick to spawn a new SpawnPoint Marker2D child at this node's origin.
@export var add_spawn_point:bool : set = set_add_spawn_point

## Section assigned to newly created spawn points. Reassign per-point in the
## inspector afterwards as needed.
@export var default_section:ArenaSection

## Mark newly created points as boss spawn positions.
@export var add_as_boss:bool = false

## Max simultaneous enemies stamped onto newly created points.
@export_range(1, 6) var default_max_simultaneous:int = 1


func set_add_spawn_point(value:bool)->void:
	if !is_inside_tree():
		return
	if !Engine.is_editor_hint():
		return

	var _point:Marker2D = Marker2D.new()
	_point.set_script(SPAWN_POINT_SCRIPT)
	_point.name = "SpawnPoint"
	add_child(_point)
	# Owner must be the edited scene root so the node is saved.
	_point.owner = get_tree().edited_scene_root
	_point.set("section", default_section)
	_point.set("boss_position", add_as_boss)
	_point.set("max_simultaneous", default_max_simultaneous)
