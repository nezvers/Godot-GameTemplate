class_name PlayerJuice
extends Node

@export var damage_receiver:DamageReceiver
@export var weapon_manager:WeaponManager
@export var enemy_damage_shake:CameraShakeResource
@export var screen_flash_command:CommandNodeResource
@export var player_damage_shake:CameraShakeResource

func _ready()->void:
	damage_receiver.health_resource.damaged.connect(on_damaged)
	weapon_manager.damage_report.connect(on_damage_report)

func on_damaged()->void:
	assert(screen_flash_command.node != null, "reference is not set")
	screen_flash_command.command("play", ["white_flash"])
	player_damage_shake.play()

## Receives data for every damage dealt
## Use for screenshake
func on_damage_report(_damage:DamageResource)->void:
	enemy_damage_shake.play()
