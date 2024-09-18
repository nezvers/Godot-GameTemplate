class_name WeaponManager
extends Node2D

## Emitted when weapon is changed
signal weapon_changed
signal damage_report(damage:DamageResource)

## Relative to this manager
## Will be modified to correct for instanced wepons
@export var projectile_parent_path:String
## Scene files that will be instanced and added to the user in disabled state
@export var auto_instance_weapons:Array[PackedScene]
## Reference passed to instanced weapons
@export var mover:MoverTopDown2D
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

func _init()->void:
	for weapon:Node in get_children():
		if !(weapon is Weapon):
			continue
		if make_unique_damage:
			weapon.damage_resource = weapon.damage_resource.duplicate()
			weapon.damage_resource.resource_name += "dup_"
		if !weapon.damage_resource.damage_report.is_connected(on_damage_report):
			weapon.damage_resource.damage_report.connect(on_damage_report)

func _ready()->void:
	mover.input_resource.switch_weapon.connect(on_switch_weapon)
	
	
	for weapon:Node in get_children():
		if !(weapon is Weapon):
			continue
		var damage_resource_dup:DamageResource = weapon.damage_resource.duplicate()
		var packed_scene:PackedScene = ScenePacker.create_package(weapon)
		auto_instance_weapons.append(packed_scene)
		remove_child(weapon)
		weapon.queue_free()
	
	for scene:PackedScene in auto_instance_weapons:
		add_new_weapon_from_scene(scene)
	
	set_weapon_index(weapon_index)

func add_new_weapon_from_scene(scene:PackedScene)->void:
	var weapon:Weapon = scene.instantiate() as Weapon
	assert(weapon != null, "failed instantiation")
	# configuration before adding to tree and calling _ready
	weapon.enabled = false
	weapon.mover = mover
	weapon.collision_mask = collision_mask
	if make_unique_damage:
		weapon.damage_resource = weapon.damage_resource.duplicate()
	if !weapon.damage_resource.damage_report.is_connected(on_damage_report):
		weapon.damage_resource.damage_report.connect(on_damage_report)
	add_child(weapon)
	weapon_list.append(weapon)


func on_switch_weapon(dir:int)->void:
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

## Collects all damage reports into one signal
func on_damage_report(damage:DamageResource)->void:
	damage_report.emit(damage)
