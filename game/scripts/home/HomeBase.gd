## Home base room (room_H00, opened from the title): no fights, the piston memory
## grid, a water gun and the weapons the player keeps between missions.
##
## Like FreshStart it runs in _enter_tree, before PlayerSpawner._ready: a stale
## carried player and transition state are cleared and the run state is reset.
## Then the player is handed the stashed weapons, and _ready puts the dropped ones
## back where they were. The state is saved whenever it changes.
class_name HomeBase
extends Node

const WATER_GUN:String = "Water Gun"

@export var player_reference:ReferenceNodeResource
@export var scene_transition_resource:SceneTransitionResource
## Run-scoped state reset on arrival (score, loot, weapon upgrades, inventory, rooms)
@export var run_resources:Array[Resource]
@export var home_base_resource:HomeBaseResource
@export var weapon_inventory:ItemCollectionResource
@export var weapon_database:ItemCollectionResource
@export var item_pickup_instance_resource:InstanceResource
## Where the water gun lies while nobody has it
@export var water_gun_spot:Node2D
@export var piston_grid:PistonGrid

## Set by depart(): the stash went out with the player, don't save it back
var _departed:bool
var _save_queued:bool

func _enter_tree()->void:
	var _carried:Node = player_reference.node
	if _carried != null:
		player_reference.remove_reference(_carried)
		if is_instance_valid(_carried) && _carried.get_parent() == null:
			_carried.queue_free()
	scene_transition_resource.next_scene_path = ""
	scene_transition_resource.entry_tag = ""
	scene_transition_resource.entry_match = null
	for _resource:Resource in run_resources:
		if _resource != null:
			_resource.reset_resource()
	home_base_resource.loadout = ""
	for _name:String in home_base_resource.stash_inventory:
		var _item:ItemResource = HomeBaseResource.find_item(weapon_database, _name)
		if _item != null && weapon_inventory.list.size() < weapon_inventory.max_items:
			weapon_inventory.list.append(_item)
		elif _item != null:
			# more than the inventory holds: lies in the control room (no "pos")
			home_base_resource.dropped.append({"item": _name})
	weapon_inventory.set_selected(0)

func _ready()->void:
	if piston_grid != null:
		piston_grid.home_base_resource = home_base_resource
		piston_grid.changed.connect(queue_save)
	weapon_inventory.updated.connect(queue_save)
	tree_exiting.connect(_on_tree_exiting)
	# pickups need the room's parent references, set during the room's _ready
	_place_pickups.call_deferred()

func _place_pickups()->void:
	var _has_water_gun:bool = _holds(WATER_GUN)
	for _entry:Dictionary in home_base_resource.dropped:
		var _item:ItemResource = HomeBaseResource.find_item(weapon_database, _entry.get("item", ""))
		if _item == null:
			continue
		_has_water_gun = _has_water_gun || _item.resource_name == WATER_GUN
		var _spot:Vector2 = water_gun_spot.global_position if water_gun_spot != null else Vector2.ZERO
		var _pos:Vector2 = _entry.get("pos", _spot)
		# a save from an older layout can put it outside the room
		_spawn_pickup(_item, _pos if _on_floor(_pos) else _spot)
	if !_has_water_gun && water_gun_spot != null:
		_spawn_pickup(HomeBaseResource.find_item(weapon_database, WATER_GUN), water_gun_spot.global_position)

func _on_floor(pos:Vector2)->bool:
	if piston_grid == null || piston_grid.floor_layer == null:
		return true
	var _floor:TileMapLayer = piston_grid.floor_layer
	return _floor.get_cell_source_id(_floor.local_to_map(_floor.to_local(pos))) != -1

func _spawn_pickup(item:ItemResource, pos:Vector2)->void:
	if item == null:
		return
	item_pickup_instance_resource.instance(func (inst:ItemPickup)->void:
		inst.item_resource = item
		inst.global_position = pos
		inst.success.connect(queue_save)
	)

func _holds(item_name:String)->bool:
	for _item:ItemResource in weapon_inventory.list:
		if _item != null && _item.resource_name == item_name:
			return true
	return false

## Pickups lying in the room (freed ones were just picked up)
func pickups()->Array[ItemPickup]:
	var _list:Array[ItemPickup] = []
	var _parent:Node = item_pickup_instance_resource.parent_reference_resource.node
	if _parent == null:
		return _list
	for _child:Node in _parent.get_children():
		if _child is ItemPickup && !_child.is_queued_for_deletion() && _child.item_resource != null:
			_list.append(_child)
	return _list

## Weapons carried and lying around, by name
func owned_weapons()->PackedStringArray:
	var _names:PackedStringArray = []
	for _item:ItemResource in weapon_inventory.list:
		if _item != null:
			_names.append(_item.resource_name)
	for _pickup:ItemPickup in pickups():
		_names.append(_pickup.item_resource.resource_name)
	return _names

## Deferred so a weapon just dropped is already lying in the room
func queue_save()->void:
	if _save_queued:
		return
	_save_queued = true
	save_state.call_deferred()

func save_state()->void:
	_save_queued = false
	if _departed:
		return
	if piston_grid != null:
		piston_grid.save_to(home_base_resource)
	var _dropped:Array[Dictionary] = []
	for _pickup:ItemPickup in pickups():
		_dropped.append({"item": _pickup.item_resource.resource_name, "pos": _pickup.global_position})
	home_base_resource.dropped = _dropped
	var _stash:PackedStringArray = []
	for _item:ItemResource in weapon_inventory.list:
		if _item != null:
			_stash.append(_item.resource_name)
	home_base_resource.stash_inventory = _stash
	home_base_resource.save_resource()

## Leaving for a mission with at most one gun: it becomes the run's loadout,
## FreshStart hands it over in the start room.
func depart()->void:
	save_state()
	var _held:PackedStringArray = home_base_resource.stash_inventory
	home_base_resource.loadout = _held[0] if !_held.is_empty() else ""
	home_base_resource.stash_inventory = PackedStringArray()
	home_base_resource.save_resource()
	_departed = true

func _on_tree_exiting()->void:
	if weapon_inventory.updated.is_connected(queue_save):
		weapon_inventory.updated.disconnect(queue_save)
	if !_departed:
		save_state()
