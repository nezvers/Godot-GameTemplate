class_name WeaponManager
extends Node2D

## Emitted when weapon is changed
signal weapon_changed

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

## List of instanced weapons available to the user
## Weapons that are already in the scene tree are added on _ready
var weapon_list:Array[Weapon]
## Shows weapon index that will be or is active
var weapon_index:int = 0
## Currently activated weapon
var current_weapon:Weapon = null


func _ready()->void:
	mover.input_resource.switch_weapon.connect(on_switch_weapon)
	for weapon:Node in get_children():
		if !(weapon is Weapon):
			continue
		# every weapon are disabled by default
		weapon.set_enabled(false)
		weapon_list.append(weapon)
	
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
