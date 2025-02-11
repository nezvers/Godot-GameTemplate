extends GPUParticles2D

func _ready()->void:
	set_emitting.call_deferred(true)
