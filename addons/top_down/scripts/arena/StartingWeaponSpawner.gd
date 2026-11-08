class_name StartingWeaponSpawner
extends Node2D

@export var exit_nodes:Array[SceneEntry]

@export var position_nodes:Array[Node2D]

@export var weapon_database:ItemCollectionResource

@export var weapon_pickup_instance_resource:InstanceResource

## An entry tag means the player walked back in through a door, not a new run
@export var scene_transition_resource:SceneTransitionResource

## A gun brought from the home base (FreshStart put it here) leaves the exits open
var weapon_inventory:ItemCollectionResource = preload("res://addons/top_down/resources/ItemCollectionResource/weapon_inventory.tres")

var collision_mask_list:Dictionary

var pickup_count:int

func _ready()->void:
	if scene_transition_resource != null && !scene_transition_resource.entry_tag.is_empty():
		return
	if weapon_inventory.list.is_empty():
		_disable_exits()
	_place_pickups()

func _disable_exits()->void:
	for _exit:SceneEntry in exit_nodes:
		_exit.visible = false
		collision_mask_list[_exit] = _exit.collision_mask
		_exit.collision_mask = 0

func _enable_exits()->void:
	for _exit:SceneEntry in exit_nodes:
		_exit.visible = true
		_exit.collision_mask = collision_mask_list[_exit]

func _place_pickups()->void:
	var _item_list:Array[WeaponItemResource]
	for _item:WeaponItemResource in weapon_database.list:
		if !_item.unlocked:
			continue
		_item_list.append(_item)
	
	_item_list.shuffle()
	assert(!_item_list.is_empty())
	assert(!position_nodes.is_empty())
	pickup_count = min(position_nodes.size(), _item_list.size())
	for i:int in pickup_count:
		var _position:Vector2 = position_nodes[i].global_position
		var _item:WeaponItemResource = _item_list[i]
		weapon_pickup_instance_resource.instance(_pickup_config.bind(_position, _item))

func _pickup_config(inst:ItemPickup, pickup_position:Vector2, item_resource:WeaponItemResource)->void:
	inst.global_position = pickup_position
	inst.item_resource = item_resource
	# co-op: every player rolls and picks up a starting weapon of its own
	# (NetEntities leaves these off the network)
	inst.set_meta(&"private_loot", true)
	inst.success.connect(_finish_pickups)

func _finish_pickups()->void:
	pickup_count -= 1
	if pickup_count > 0 || collision_mask_list.is_empty():
		return
	_enable_exits()
