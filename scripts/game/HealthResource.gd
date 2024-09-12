class_name HealthResource
extends Resource

signal damaged
signal dead
signal hp_changed

@export var hp:float = 5
@export var reset_hp:float = 5
@export var is_dead:bool

func reset()->void:
	is_dead = false
	hp = reset_hp
	hp_changed.emit()

func take_damage(damage_resource:DamageResource)->void:
	if is_dead:
		return
	hp -= damage_resource.get_total_damage()
	hp_changed.emit()
	damaged.emit()
	if hp <= 0.0:
		is_dead = true
		dead.emit()
