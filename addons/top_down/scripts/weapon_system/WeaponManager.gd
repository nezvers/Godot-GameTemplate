class_name WeaponManager
extends Node2D

## Emitted when weapon is changed
signal weapon_changed


## Reference passed to instanced weapons
@export var resource_node:ResourceNode

## Passed to instantiated weapons, that pass it to projectiles
## TODO: Need to remove passing chain
@export_flags_2d_physics var collision_mask:int

@export var item_pickup_instance_resource:InstanceResource

## Run-scoped upgrade levels; optional
@export var weapon_upgrade_resource:WeaponUpgradeResource

## Used only while the inventory is empty (fists); not an inventory item
@export var default_weapon_scene:PackedScene

## List of instanced weapons available to the user
## Weapons that are already in the scene tree are added on _ready
var weapon_list:Array[Weapon]

## Necessary to check if weapon is created
var weapon_dictionary:Dictionary

## Currently activated weapon
var current_weapon:Weapon = null

## Instance of default_weapon_scene, kept out of weapon_list and weapon_dictionary
var default_weapon:Weapon = null

var weapon_inventory:ItemCollectionResource

var input_resource:InputResource

## Store scene in memory to "load" faster
var weapon_scene_cache:Array[PackedScene]

## Multiplies every weapon's damage on top of its upgrade level (meta-upgrades)
var meta_damage_multiply:float = 1.0

func _ready()->void:
	# TODO: Prepare for use with PoolNode
	request_ready()
	
	_setup_weapon_inventory()
	_setup_input_connection()
	if weapon_upgrade_resource != null:
		weapon_upgrade_resource.updated.connect(_apply_all_upgrades)

func _exit_tree() -> void:
	weapon_inventory.selected_changed.disconnect(set_weapon_index)
	weapon_inventory.updated.disconnect(_update_weapon_inventory)
	weapon_inventory.removed.disconnect(_on_remove)
	input_resource.switch_weapon.disconnect(_on_switch_weapon)
	input_resource.drop_weapon.disconnect(drop_weapon)
	if weapon_upgrade_resource != null:
		weapon_upgrade_resource.updated.disconnect(_apply_all_upgrades)

func _setup_weapon_inventory()->void:
	weapon_inventory = resource_node.get_resource("weapons")
	assert(weapon_inventory != null)
	
	for _child in get_children():
		remove_child(_child)
		_child.queue_free()
	
	## TODO: Optimize instead of recreating every time
	weapon_dictionary.clear()
	weapon_list.clear()
	weapon_scene_cache.clear()
	current_weapon = null
	default_weapon = null
	if default_weapon_scene != null:
		default_weapon = _add_new_weapon_from_scene(default_weapon_scene)
	for _item:ItemResource in weapon_inventory.list:
		var _path:String = _item.scene_path
		var _scene:PackedScene = load(_path)
		weapon_scene_cache.append(_scene)
		var _weapon:Weapon = _add_new_weapon_from_scene(_scene)
		weapon_list.append(_weapon)
		weapon_dictionary[_path] = _weapon
	
	weapon_inventory.updated.connect(_update_weapon_inventory)
	weapon_inventory.removed.connect(_on_remove)
	weapon_inventory.selected_changed.connect(set_weapon_index)
	set_weapon_index()

func _setup_input_connection()->void:
	input_resource = resource_node.get_resource("input")
	assert(input_resource != null)
	
	input_resource.switch_weapon.connect(_on_switch_weapon)
	input_resource.drop_weapon.connect(drop_weapon)

func _add_new_weapon_from_scene(scene:PackedScene)->Weapon:
	var _weapon:Weapon = scene.instantiate() as Weapon
	assert(_weapon != null, "failed instantiation")
	# configuration before adding to tree and calling _ready
	_weapon.enabled = false
	_weapon.resource_node = resource_node
	_weapon.collision_mask = collision_mask
	_weapon.damage_data_resource = _weapon.damage_data_resource.duplicate()
	_apply_upgrade(_weapon, scene.resource_path)
	
	add_child(_weapon)
	return _weapon

## Meta-upgrade damage bonus on every weapon, set by MetaStats.
func set_meta_damage_multiply(value:float)->void:
	meta_damage_multiply = value
	_apply_upgrade(default_weapon, "")
	_apply_all_upgrades()

## Scales damage and fire interval from the weapon's upgrade level.
## The scene's interval is kept in meta so repeated upgrades don't compound.
func _apply_upgrade(weapon:Weapon, scene_path:String)->void:
	if weapon == null:
		return
	if weapon_upgrade_resource == null:
		weapon.damage_data_resource.upgrade_multiply = meta_damage_multiply
		return
	weapon.damage_data_resource.upgrade_multiply = weapon_upgrade_resource.damage_multiplier(scene_path) * meta_damage_multiply
	var _interval_node:Node = weapon.get_node_or_null("WeaponTrigger/ProjectileInterval")
	if _interval_node == null:
		return
	if !_interval_node.has_meta("base_interval"):
		_interval_node.set_meta("base_interval", _interval_node.interval)
	_interval_node.interval = _interval_node.get_meta("base_interval") * weapon_upgrade_resource.interval_multiplier(scene_path)

func _apply_all_upgrades()->void:
	for _path:String in weapon_dictionary:
		_apply_upgrade(weapon_dictionary[_path], _path)

## Scene path of the selected weapon, or empty without one.
func get_current_weapon_path()->String:
	for _path:String in weapon_dictionary:
		if weapon_dictionary[_path] == current_weapon:
			return _path
	return ""

func _update_weapon_inventory()->void:
	weapon_list.clear()
	for _item:ItemResource in weapon_inventory.list:
		var _path:String = _item.scene_path
		if weapon_dictionary.has(_path):
			var _weapon:Weapon = weapon_dictionary[_path]
			weapon_list.append(_weapon)
			continue
		var _scene:PackedScene = load(_path)
		weapon_scene_cache.append(_scene)
		var _weapon:Weapon = _add_new_weapon_from_scene(_scene)
		weapon_list.append(_weapon)
		weapon_dictionary[_path] = _weapon
	
	set_weapon_index()

func test_drop()->void:
	drop_weapon()

## Drops the selected weapon as a pickup at the actor's feet; fists stay.
func drop_weapon()->void:
	if weapon_inventory.list.is_empty():
		return
	weapon_inventory.drop()

func _on_remove(item:WeaponItemResource, is_dropped:bool)->void:
	var _path:String = item.scene_path
	if !weapon_dictionary.has(_path):
		return
	var _weapon:Weapon = weapon_dictionary[_path]
	weapon_dictionary.erase(_path)
	remove_child(_weapon)
	_weapon.queue_free()
	
	if !is_dropped:
		return
	# TODO: drop pickup
	var _config_callback:Callable = func (inst:ItemPickup):
		inst.item_resource = item
		inst.global_position = global_position
	
	item_pickup_instance_resource.instance(_config_callback)

func _on_switch_weapon(dir:int)->void:
	if dir == 1:
		weapon_inventory.set_selected(weapon_inventory.selected -1)
	elif dir == -1:
		weapon_inventory.set_selected(weapon_inventory.selected +1)

func set_weapon_index()->void:
	if is_instance_valid(current_weapon):
		current_weapon.set_enabled(false)
	current_weapon = null
	
	if weapon_list.is_empty():
		current_weapon = default_weapon
	else:
		current_weapon = weapon_list[weapon_inventory.selected]
	if current_weapon == null:
		return
	current_weapon.set_enabled(true)
	weapon_changed.emit()

func get_current_damage()->DamageResource:
	return current_weapon.damage_resource
