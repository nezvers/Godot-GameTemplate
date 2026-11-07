class_name PlayerSpawner
extends Node2D

## Reference to a player. If player object doesn't exist it will be spawned
@export var player_reference:ReferenceNodeResource
@export var player_instance_resource:InstanceResource
@export var scene_transition_resource:SceneTransitionResource

func _ready()->void:
	assert(player_reference != null)
	assert(player_instance_resource != null)
	
	scene_transition_resource.change_scene.connect(on_scene_transition)
	
	if player_reference.node != null:
		## Allow doors to register themselves.
		on_player_scene_entry.call_deferred()
		return
	
	if RunSession.is_resuming():
		## Continue: the saved door registers itself in its _ready, place the party there.
		_spawn_resumed.call_deferred()
		return
	
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = global_position
	var _player:Node2D = player_instance_resource.instance(_config_callback)
	_player.ready.connect(_on_fresh_spawn_ready, CONNECT_ONE_SHOT)

func _on_fresh_spawn_ready()->void:
	RunSession.on_party_placed(owner, "")

func _spawn_resumed()->void:
	var _door:Node2D = scene_transition_resource.entry_match
	var _tag:String = RunSession.resume_entry_tag()
	var _at:Vector2 = global_position
	if !_tag.is_empty() && is_instance_valid(_door):
		_at = _door.global_position
	else:
		_tag = ""
	var _player:Node2D = player_instance_resource.instance(func (inst:Node2D)->void:
		inst.global_position = _at)
	_player.ready.connect(func ()->void:
		RunSession.finish_resume(_player)
		RunSession.on_party_placed(owner, _tag), CONNECT_ONE_SHOT)

func on_player_scene_entry()->void:
	assert(scene_transition_resource.entry_match != null)
	assert(scene_transition_resource.entry_match.is_inside_tree())
	assert(!scene_transition_resource.entry_match.is_queued_for_deletion())
	
	var _player:Node2D = player_reference.node
	_player.global_position = scene_transition_resource.entry_match.global_position
	player_instance_resource.parent_reference_resource.node.add_child(_player)
	RunSession.on_party_placed(owner, scene_transition_resource.entry_tag)
	## Arrival consumed: a later menu/game over load isn't mistaken for a door entry.
	scene_transition_resource.next_scene_path = ""

func on_scene_transition()->void:
	var _parent:Node = player_instance_resource.parent_reference_resource.node
	var _player:Node = player_reference.node
	_parent.remove_child.call_deferred(_player)
	scene_transition_resource.change_scene.disconnect(on_scene_transition)
	Transition.change_scene(scene_transition_resource.next_scene_path)
