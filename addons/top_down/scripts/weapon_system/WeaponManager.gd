class_name WeaponManager
extends Node2D

## Emitted when weapon is changed
signal weapon_changed

## Scene files that will be instanced and added to the user in disabled state
@export var auto_instance_weapons:Array[PackedScene]

## Reference passed to instanced weapons
@export var resource_node:ResourceNode

## Passed to instantiated weapons, that pass it to projectiles
## TODO: Need to remove passing chain
@export_flags_2d_physics var collision_mask:int

## In case users share the same weapons it's better to make damage_resource unique
## That removes opion to tweak values from Godot Editor while a game is running
@export var make_unique_damage:bool = true

## List of instanced weapons available to the user
## Weapons that are already in the scene tree are added on _ready
var weapon_list:Array[Weapon]

## Shows weapon index that will be or is active
var weapon_index:int = 0

## Currently activated weapon
var current_weapon:Weapon = null


func _ready()->void:
	var _child_weapons:Array[PackedScene]
	for weapon:Node in get_children():
		if !(weapon is Weapon):
			continue
		# create scene from child weapon
		var _packed_scene:PackedScene = ScenePacker.create_package(weapon)
		_child_weapons.append(_packed_scene)
		remove_child(weapon)
		weapon.queue_free()
	
	# BUG: workaround new instance gets modified array from previous instance
	auto_instance_weapons = auto_instance_weapons.duplicate()
	
	# Insert child scenes in array beginning
	for i:int in _child_weapons.size():
		var _packed_scene:PackedScene = _child_weapons[i]
		auto_instance_weapons.insert(i, _packed_scene)
	
	for _scene:PackedScene in auto_instance_weapons:
		add_new_weapon_from_scene(_scene)
	
	set_weapon_index(weapon_index)
	
	_setup_input_connection()
	# in case used with PoolNode
	resource_node.ready.connect(_setup_input_connection)

func _setup_input_connection()->void:
	var _input_resource:InputResource = resource_node.get_resource("input")
	assert(_input_resource != null)
	
	_input_resource.switch_weapon.connect(_on_switch_weapon)
	
	# in case used with PoolNode
	tree_exiting.connect(_input_resource.switch_weapon.disconnect.bind(_on_switch_weapon), CONNECT_ONE_SHOT)

func add_new_weapon_from_scene(scene:PackedScene)->void:
	var _weapon:Weapon = scene.instantiate() as Weapon
	assert(_weapon != null, "failed instantiation")
	# configuration before adding to tree and calling _ready
	_weapon.enabled = false
	_weapon.resource_node = resource_node
	_weapon.collision_mask = collision_mask
	if make_unique_damage:
		_weapon.damage_data_resource = _weapon.damage_data_resource.duplicate()
		_weapon.damage_data_resource.resource_name += "_dup"
	
	add_child(_weapon)
	weapon_list.append(_weapon)


func _on_switch_weapon(dir:int)->void:
	if dir == 1:
		set_weapon_index(weapon_index +1)
	elif dir == -1:
		set_weapon_index(weapon_index -1)

func set_weapon_index(value:int)->void:
	if weapon_list.is_empty():
		weapon_index = -1
		return
	
	if current_weapon != null:
		current_weapon.set_enabled(false)
		current_weapon = null
	
	weapon_index = abs(value + weapon_list.size()) % weapon_list.size()
	
	current_weapon = weapon_list[weapon_index]
	current_weapon.set_enabled(true)
	weapon_changed.emit()

func get_current_damage()->DamageResource:
	return current_weapon.damage_resource
