class_name CameraShakeResource
extends Resource

@export var length:float = 0.5
@export var frequency:Curve
@export var amplitude:Curve
@export_range (0.0, 360.0) var angleFrom:float = 0.0
@export_range (0.0, 360.0) var angleto:float = 360.0
@export var camera_reference:ReferenceNodeResource
@export var tween_resource:TweenValueResource

var dir:Vector2

func play()->void:
	if camera_reference.node == null:
		return
	
	var angle = deg_to_rad(lerp(angleFrom, angleto, randf())) * TAU
	dir = Vector2(cos(angle), sin(angle))
	
	if tween_resource.value != null:
		tween_resource.value.kill()
	
	tween_resource.value = camera_reference.node.create_tween().bind_node(camera_reference.node)
# warning-ignore:return_value_discarded
	tween_resource.value.tween_method(sample, 0.0, 1.0, length)

func sample(t:float)->void:
	var offset:Vector2 = sin(TAU * frequency.sample(t) * length * (1.0 - t)) * amplitude.sample(t) * dir
	camera_reference.node.offset = offset
