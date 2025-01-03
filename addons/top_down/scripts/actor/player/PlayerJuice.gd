class_name PlayerJuice
extends Node

@export var resource_node:ResourceNode
@export var weapon_manager:WeaponManager
@export var enemy_damage_shake:CameraShakeResource
@export var screen_flash_animation_player:ReferenceNodeResource
@export var player_damage_shake:CameraShakeResource

func _ready()->void:
	weapon_manager.damage_report.connect(on_damage_report)
	
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if _health_resource != null:
		_health_resource.damaged.connect(on_damaged)


func on_damaged()->void:
	assert(screen_flash_animation_player.node != null, "reference is not set")
	# TODO: find a way to expose what functions are available
	screen_flash_animation_player.node.play("white_flash")
	player_damage_shake.play()

## Receives data for every damage dealt
## Use for screenshake
func on_damage_report(_damage:DamageResource)->void:
	enemy_damage_shake.play()
