class_name WeaponManager
extends Node2D

## Emitted when weapon is changed
signal weapon_changed


## Reference passed to instanced weapons
@export var resource_node:ResourceNode

## Passed to instantiated weapons, that pass it to projectiles
## TODO: Need to remove passing chain
@export_flags_2d_physics var collision_mask:int


## List of instanced weapons available to the user
## Weapons that are already in the scene tree are added on _ready
var weapon_list:Array[Weapon]

## Necessary to check if weapon is created
var weapon_dictionary:Dictionary

## Currently activated weapon
var current_weapon:Weapon = null

var weapon_inventory:ItemCollectionResource

var input_resource:InputResource

## Store scene in memory to "load" faster
var weapon_scene_cache:Array[PackedScene]

func _ready()->void:
	# TODO: Prepare for use with PoolNode
	request_ready()
	
	_setup_weapon_inventory()
	_setup_input_connection()

func _exit_tree() -> void:
	weapon_inventory.selected_changed.disconnect(set_weapon_index)
	weapon_inventory.updated.disconnect(_update_weapon_inventory)
	input_resource.switch_weapon.disconnect(_on_switch_weapon)

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
	for _item:ItemResource in weapon_inventory.list:
		var _path:String = _item.scene_path
		var _scene:PackedScene = load(_path)
		weapon_scene_cache.append(_scene)
		var _weapon:Weapon = _add_new_weapon_from_scene(_scene)
		weapon_list.append(_weapon)
		weapon_dictionary[_path] = _weapon
	
	weapon_inventory.updated.connect(_update_weapon_inventory)
	
	weapon_inventory.selected_changed.connect(set_weapon_index)
	set_weapon_index()

func _setup_input_connection()->void:
	input_resource = resource_node.get_resource("input")
	assert(input_resource != null)
	
	input_resource.switch_weapon.connect(_on_switch_weapon)

func _add_new_weapon_from_scene(scene:PackedScene)->Weapon:
	var _weapon:Weapon = scene.instantiate() as Weapon
	assert(_weapon != null, "failed instantiation")
	# configuration before adding to tree and calling _ready
	_weapon.enabled = false
	_weapon.resource_node = resource_node
	_weapon.collision_mask = collision_mask
	_weapon.damage_data_resource = _weapon.damage_data_resource.duplicate()
	
	add_child(_weapon)
	return _weapon

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

func _on_switch_weapon(dir:int)->void:
	if dir == 1:
		weapon_inventory.set_selected(weapon_inventory.selected -1)
	elif dir == -1:
		weapon_inventory.set_selected(weapon_inventory.selected +1)

func set_weapon_index()->void:
	if weapon_list.is_empty():
		return
	
	if current_weapon != null:
		current_weapon.set_enabled(false)
		current_weapon = null
	
	current_weapon = weapon_list[weapon_inventory.selected]
	current_weapon.set_enabled(true)
	weapon_changed.emit()

func get_current_damage()->DamageResource:
	return current_weapon.damage_resource
