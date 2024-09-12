extends Node

@export var weapon:Weapon
@export var interval:float = 0.5

var tween:Tween

func _ready()->void:
	weapon.projectile_created.connect(start)

## Disables weapon's ability to spawn and plays an attack animation
func start()->void:
	weapon.enabled = false
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_callback(timeout).set_delay(interval)

## Animation end enables weapon's ability to spawn projectiles
func timeout()->void:
	weapon.enabled = true
	if weapon.can_spawn():
		weapon.spawn_projectile()
