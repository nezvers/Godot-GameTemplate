class_name ProjectileLifetime
extends Node

@export var time:float = 1.0
@export var projectile:Projectile2D

var tween:Tween

func _ready()->void:
	if !(time > 0.0):
		return
	
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.tween_callback(_on_timeout).set_delay(time)

func _on_timeout()->void:
	projectile.prepare_exit()
