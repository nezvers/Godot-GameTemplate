extends Node

signal actor_died

@export var resource_node:ResourceNode
@export var mover:MoverTopDown2D
@export var sprite_flip:SpriteFlip
@export var flash_animation_player:AnimationPlayer
@export var flash_animation:StringName
@export var sound_resource_damage:SoundResource
@export var sound_resource_dead:SoundResource
@export var dead_vfx_instance_resource:InstanceResource

func _ready()->void:
	var _health_resource:HealthResource = resource_node.get_resource("health")
	# workaround to retrigger color flash - stop and then play again
	_health_resource.damaged.connect(flash_animation_player.stop)
	_health_resource.damaged.connect(flash_animation_player.play.bind(flash_animation))
	
	# disable moving
		#_health_resource.dead.connect(mover.set_enabled.bind(false))
	# remove character
	_health_resource.dead.connect(_play_dead)
	
	# Because both are resources they can still be in a memory and connections are still active
	if !_health_resource.dead.is_connected(sound_resource_dead.play_managed):
		_health_resource.dead.connect(sound_resource_dead.play_managed)
	if !_health_resource.damaged.is_connected(sound_resource_damage.play_managed):
		_health_resource.damaged.connect(sound_resource_damage.play_managed)
	
	# in case used with PoolNode
	request_ready()
	flash_animation_player.play("RESET")
	tree_exiting.connect(_remove_connections.bind(_health_resource), CONNECT_ONE_SHOT)

func _remove_connections(health_resource:HealthResource)->void:
	health_resource.damaged.disconnect(flash_animation_player.stop)
	health_resource.damaged.disconnect(flash_animation_player.play.bind(flash_animation))
	# disable moving
		#health_resource.dead.disconnect(mover.set_enabled.bind(false))
	# remove character
	health_resource.dead.disconnect(_play_dead)
	
	# Because both are resources they can still be in a memory and connections are still active
	if health_resource.dead.is_connected(sound_resource_dead.play_managed):
		health_resource.dead.disconnect(sound_resource_dead.play_managed)
	if health_resource.damaged.is_connected(sound_resource_damage.play_managed):
		health_resource.damaged.disconnect(sound_resource_damage.play_managed)

func _play_dead()->void:
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = owner.global_position
		inst.scale.x = sprite_flip.dir
	
	dead_vfx_instance_resource.instance.call_deferred(_config_callback)
	actor_died.emit()
