## Every enemy leaves its own corpse instead of borrowing another enemy's death,
## and the fists show a fist and throw a punch.
##   Godot --headless --path . res://game/tests/asset_variants_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const ROOM_START:String = "res://game/scenes/room_start.tscn"
const ACTORS:String = TD + "resources/InstanceResources/actors/"
const DEAD:String = TD + "scenes/vfx/dead/"

## actor instance resource -> death scene it has to spawn
const DEATHS:Dictionary = {
	"bloater_instance_resource.tres": "bloater_dead.tscn",
	"acid_slime_instance_resource.tres": "acid_slime_dead.tscn",
	"giant_zombie_instance_resource.tres": "giant_zombie_dead.tscn",
	"broodmother_instance_resource.tres": "broodmother_dead.tscn",
	"plague_mother_instance_resource.tres": "plague_mother_dead.tscn",
}

var failures:int = 0
var checks:int = 0
var _room:Node

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	(load(TD + "resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	_check_fists()
	_room = (load(ROOM_START) as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)
	var _player:Node2D = (load(TD + "resources/ReferenceNodeResources/player_reference.tres") as ReferenceNodeResource).node
	check(_player != null, "player spawned")
	if _player != null:
		for _actor:String in DEATHS:
			await _check_death(_actor, DEATHS[_actor], _player.global_position + Vector2(0, 40))
	_finish()

func _check_fists()->void:
	var _fists:Node = (load(TD + "scenes/weapons/fists.tscn") as PackedScene).instantiate()
	var _sprite:Sprite2D = _fists.get_node("RotatedNode/Sprite2D")
	check(_fists.get_node("RotatedNode").visible, "fists are drawn in hand")
	check(_sprite.texture != null && _sprite.texture.resource_path.get_file() == "fist_0.png", "fists hold the fist sprite")
	check(_fists.get_node("WeaponTrigger/AnimationTrigger").animation_list == [&"punch"], "fists jab on attack")
	_fists.free()
	var _punch:Node = (load(TD + "scenes/projectiles/fist_slash.tscn") as PackedScene).instantiate()
	var _punch_sprite:Sprite2D = _punch.get_node("RotatedNode/Sprite2D")
	check(_punch_sprite.texture.resource_path.get_file() == "punch_16x16_strip4.png", "fist projectile draws the punch impact")
	_punch.free()

func _check_death(actor_file:String, dead_file:String, position:Vector2)->void:
	var _actor_resource:InstanceResource = load(ACTORS + actor_file)
	var _actor:Node2D = _actor_resource.instance(func (inst:Node2D)->void: inst.global_position = position)
	await _frames(3)
	(_actor.get_node("ResourceNode").get_resource("health") as HealthResource).insta_kill()
	await _frames(3)
	var _corpses:Array[Node] = _find_scene(get_tree().root, DEAD + dead_file)
	check(!_corpses.is_empty(), "%s leaves %s" % [actor_file, dead_file])
	for _corpse:Node in _corpses:
		_corpse.queue_free()
	await _frames(2)

func _find_scene(node:Node, scene_path:String)->Array[Node]:
	var _found:Array[Node] = []
	if node.scene_file_path == scene_path && node.is_inside_tree():
		_found.append(node)
	for _child:Node in node.get_children():
		_found.append_array(_find_scene(_child, scene_path))
	return _found

func _finish()->void:
	print("asset_variants_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
