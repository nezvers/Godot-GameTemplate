class_name WeaponTrigger
extends Node

signal shoot_event

## Toggle weapons capability to spawn projectile
@export var enabled:bool = true
@export var weapon:Weapon
@export var projectile_spawner:ProjectileSpawner
## Sound of shooting projectile
@export var sound_resource:SoundResource
@export var can_shoot:bool = true


func _ready()->void:
	weapon.enabled_changed.connect(set_enabled)
	set_enabled(weapon.enabled)
	projectile_spawner.damage_resource = weapon.damage_resource
	projectile_spawner.collision_mask = Bitwise.append_flags(projectile_spawner.collision_mask, weapon.collision_mask)

## Toggle connections to the action input and controls visibility
func set_enabled(value:bool)->void:
	enabled = value
	if enabled:
		if !weapon.mover.input_resource.action_pressed.is_connected(on_shoot):
			weapon.mover.input_resource.action_pressed.connect(on_shoot)
	else:
		if weapon.mover.input_resource.action_pressed.is_connected(on_shoot):
			weapon.mover.input_resource.action_pressed.disconnect(on_shoot)

func on_shoot()->void:
	if !can_shoot || !weapon.enabled:
		return
	shoot_event.emit()
	projectile_spawner.projectile_position = weapon.global_position
	projectile_spawner.direction = weapon.mover.input_resource.aim_direction
	projectile_spawner.spawn()
	sound_resource.play_managed()

func set_can_shoot(value:bool)->void:
	can_shoot = value

func can_retrigger()->bool:
	return weapon.mover.input_resource.action

func get_direction()->Vector2:
	return weapon.mover.input_resource.aim_direction
