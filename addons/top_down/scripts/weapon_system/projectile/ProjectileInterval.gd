extends Node

@export var weapon_trigger:WeaponTrigger
@export var interval:float = 0.5

var tween:Tween

func _ready()->void:
	weapon_trigger.shoot_event.connect(start)

## Disables weapon's ability to spawn and plays an attack animation
func start()->void:
	weapon_trigger.can_shoot = false
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_callback(timeout).set_delay(interval)

## enables trigger to shoot projectiles
func timeout()->void:
	weapon_trigger.can_shoot = true
	if weapon_trigger.can_retrigger():
		weapon_trigger.on_shoot()
