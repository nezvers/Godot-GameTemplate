class_name BloodTrail
extends Node

## Node whose position is used for placing particles
@export var position_node:Node2D

@export var blood_particle_instance:InstanceResource

var particles:GPUParticles2D

func _ready() -> void:
	var _config_callback:Callable = func (inst:Node)->void:
		particles = inst
		particles.emitting = true
		particles.global_position = position_node.global_position
	
	blood_particle_instance.instance(_config_callback)
	
	# for use with PoolNode
	request_ready()

func _physics_process(_delta: float) -> void:
	if particles == null:
		return
	
	particles.global_position = position_node.global_position

func _exit_tree() -> void:
	particles.emitting = false
	var _tween:Tween = particles.create_tween()
	_tween.tween_callback(particles.queue_free).set_delay(3.0)
	particles = null
