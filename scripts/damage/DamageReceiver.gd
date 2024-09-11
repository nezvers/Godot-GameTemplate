class_name DamageReceiver
extends Area2D

signal received_impulse(value:Vector2)

@export var health_resource:HealthResource
## Can't be damaged this time after taking a damage
@export var damage_cooldown:float = 0.0

var last_time:float


func _ready()->void:
	health_resource.reset()

func take_damage(damage_resource:DamageResource)->void:
	if health_resource.is_dead:
		return
	var time:float = Time.get_ticks_msec() * 0.001
	if last_time + damage_cooldown > time:
		return
	last_time = time
	health_resource.take_damage(damage_resource)
	received_impulse.emit(damage_resource.direction * damage_resource.kickback_strength)
