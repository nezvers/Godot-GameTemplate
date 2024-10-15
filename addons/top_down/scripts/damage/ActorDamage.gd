extends Node

@export var resource_node:ResourceNode
@export var mover:MoverTopDown2D
@export var sprite_flip:SpriteFlip
@export var flash_animation_player:AnimationPlayer
@export var flash_animation:StringName
@export var sound_resource_damage:SoundResource
@export var sound_resource_dead:SoundResource
@export var dead_vfx_scene:PackedScene
@export var dead_vfx_parent_path:NodePath

func _ready()->void:
	
	var _health_resource:HealthResource = resource_node.get_resource("health")
	_health_resource.damaged.connect(flash_animation_player.stop)
	_health_resource.damaged.connect(flash_animation_player.play.bind(flash_animation))
	# disable moving
	_health_resource.dead.connect(mover.set_enabled.bind(false))
	# remove character
	_health_resource.dead.connect(play_dead)
	
	# Because both are resources they can still be in a memory and connections are still active
	if !_health_resource.dead.is_connected(sound_resource_dead.play_managed):
		_health_resource.dead.connect(sound_resource_dead.play_managed)
	if !_health_resource.damaged.is_connected(sound_resource_damage.play_managed):
		_health_resource.damaged.connect(sound_resource_damage.play_managed)

func play_dead()->void:
	var vfx_inst:Node2D = dead_vfx_scene.instantiate()
	var vfx_parent:Node2D = get_node(dead_vfx_parent_path)
	vfx_parent.add_child(vfx_inst)
	vfx_inst.global_position = owner.global_position
	vfx_inst.scale.x = sprite_flip.dir
	# RestartScene in level calls for scene restart
	owner.queue_free()
