class_name HealthResource
extends Resource

signal damaged
signal dead
signal hp_changed

@export var hp:int = 5
@export var reset_hp:int = 5
@export var is_dead:bool

func reset()->void:
	is_dead = false
	hp = reset_hp
	hp_changed.emit()

func take_damage(value:int)->void:
	if is_dead:
		return
	hp -= value
	hp_changed.emit()
	damaged.emit()
	if hp <= 0:
		is_dead = true
		dead.emit()
