class_name ActorDamage
extends Node

signal actor_died

@export var resource_node:ResourceNode
@export var sprite_flip:SpriteFlip
@export var flash_animation_player:AnimationPlayer
@export var flash_animation:StringName
@export var sound_resource_damage:SoundResource
@export var sound_resource_dead:SoundResource
@export var dead_vfx_instance_resource:InstanceResource

func _ready()->void:
	var _health_resource:HealthResource = resource_node.get_resource("health")
	# workaround to retrigger color flash - stop and then play again
	_health_resource.damaged.connect(_play_damaged)
	
	# remove character
	_health_resource.dead.connect(_play_dead)
	
	# in case used with PoolNode
	request_ready()
	flash_animation_player.play("RESET")
	tree_exiting.connect(_remove_connections.bind(_health_resource), CONNECT_ONE_SHOT)

func _remove_connections(health_resource:HealthResource)->void:
	health_resource.damaged.disconnect(_play_damaged)
	# remove character
	health_resource.dead.disconnect(_play_dead)

func _play_damaged()->void:
	flash_animation_player.stop()
	flash_animation_player.play(flash_animation)
	sound_resource_damage.play_managed()

func _play_dead()->void:
	sound_resource_dead.play_managed()
	
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = owner.global_position
		inst.scale.x = sprite_flip.dir
	
	dead_vfx_instance_resource.instance.call_deferred(_config_callback)
	actor_died.emit()
