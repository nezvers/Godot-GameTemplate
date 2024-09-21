class_name HealthResource
extends Resource

signal damaged
signal dead
signal hp_changed
signal full

@export var hp:float = 5
@export var max_hp:float = 5

@export var reset_hp:float = 5
@export var reset_max_hp:float = 5
@export var is_dead:bool

func reset()->void:
	is_dead = false
	hp = reset_hp
	max_hp = reset_max_hp
	hp_changed.emit()

func is_full()->bool:
	return hp == max_hp

func add_hp(value:float)->void:
	hp = clamp(hp + value, 0.0, max_hp)
	hp_changed.emit()
	if value < 0.0:
		damaged.emit()
	if hp == 0.0:
		dead.emit()
		return
	if hp == max_hp:
		full.emit()
		return

func take_damage(damage_resource:DamageResource)->void:
	if is_dead:
		return
	hp -= damage_resource.get_total_damage()
	hp_changed.emit()
	damaged.emit()
	if hp <= 0.0:
		is_dead = true
		dead.emit()
