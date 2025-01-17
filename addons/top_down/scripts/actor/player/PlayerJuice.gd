class_name PlayerJuice
extends Node

@export var resource_node:ResourceNode
@export var enemy_damage_shake:CameraShakeResource
@export var screen_flash_animation_player:ReferenceNodeResource
@export var player_damage_shake:CameraShakeResource

func _ready()->void:
	# Player health is globaly used - it is the same when restarting and moving between scenes
	var _health_resource:HealthResource = resource_node.get_resource("health")
	assert(_health_resource != null)
	_health_resource.damaged.connect(_on_damaged)
	
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	assert(_damage_resource != null)
	_damage_resource.report_damage.connect(_on_damage_report)
	
	#  in case used with PoolNode
	request_ready()
	tree_exiting.connect(_health_resource.damaged.disconnect.bind(_on_damaged), CONNECT_ONE_SHOT)
	tree_exiting.connect(_damage_resource.report_damage.disconnect.bind(_on_damage_report), CONNECT_ONE_SHOT)


func _on_damaged()->void:
	assert(screen_flash_animation_player.node != null, "reference is not set")
	# TODO: find a way to expose what functions are available
	screen_flash_animation_player.node.play("white_flash")
	player_damage_shake.play()

## Receives data for every damage dealt
## Use for screenshake
func _on_damage_report(_damage:DamageDataResource)->void:
	enemy_damage_shake.play()
