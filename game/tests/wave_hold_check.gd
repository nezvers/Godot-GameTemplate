## Plays room_A02 headless: starts the first fight and checks that no enemy
## (or spawn mark) appears while the wave start zen animation plays, and that
## spawning begins once it has finished.
##   Godot --headless --path . res://game/tests/wave_hold_check.tscn
extends Node

const TD:String = "res://addons/top_down/"

var failures:int = 0
var checks:int = 0

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	var _actions:ActionResource = load(TD + "resources/global_resources/action_resource.tres")
	_actions.reset_resource()
	var _room:Node = (load("res://game/scenes/room_A02.tscn") as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)
	var _announcer:ZenAnnouncer = _room.get_node("ZenAnnouncer")
	var _section:ArenaSection = _room.get_node("EnemyManager/Section1")
	var _anim_done:Array[bool] = [false]
	_announcer.child_entered_tree.connect(func (node:Node)->void:
		if node.scene_file_path.get_file() == _announcer.wave_start_scene.resource_path.get_file():
			node.tree_exiting.connect(func ()->void: _anim_done[0] = true)
	)

	_section.try_start()
	check(_section.fight_active, "fight started")
	check(_section.spawn_holds > 0, "spawning held for the wave announcement")
	var _spawned_early:bool = false
	var _elapsed:float = 0.0
	while !_anim_done[0] && _elapsed < 15.0:
		await get_tree().physics_frame
		_elapsed += get_physics_process_delta_time()
		if _section.pending_spawns > 0 || !ActiveEnemy.root.nodes.is_empty():
			_spawned_early = true
	check(_anim_done[0], "wave start animation finished (%.1fs)" % _elapsed)
	check(!_spawned_early, "nothing spawned during the announcement")
	await _frames(5)
	check(_section.spawn_holds == 0, "spawning released")
	check(_section.pending_spawns > 0 || !ActiveEnemy.root.nodes.is_empty(), "spawning began after the announcement")
	print("wave_hold_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
