class_name TriggerSceneChanger
extends Node

@export var area:Area2D
@export_flags_2d_physics var target_layer:int
@export var scene_path:String

func _ready() -> void:
	area.collision_mask = Bitwise.append_flags(area.collision_mask, target_layer)
	area.area_entered.connect(on_entering)

func on_entering(_area:Area2D)->void:
	# Called on physics frame and not a good moment to free objects
	change_scene.call_deferred()

func change_scene()->void:
	var next_scene:PackedScene = load(scene_path)
	assert(next_scene != null)
	var scene_tree:SceneTree = get_tree()
	var err:int = scene_tree.change_scene_to_packed(next_scene)
	assert(err == 0)
