class_name DamageResource
extends Resource

signal damage_received(damage:DamageResource)

@export var value:float = 1
@export var projectile_multiply:float = 1.0
@export var critical_multiply:float = 1.5
@export var critical_chance:float = 0.3
@export var direction:Vector2
@export var kickback_strength:float

## An information for a damage report
var is_critical:bool = false
## Exploiting that array is shared reference
## it will collect all same generation damages
var hit_list:Array

func get_total_damage()->float:
	# TODO: insert your open world MMO RPG damage calculation here
	is_critical = randf() < critical_chance
	if !is_critical:
		critical_multiply = 1.0
	
	return value * critical_multiply * projectile_multiply

## Receiving end should trigger this function
## TODO: include more receiving end information
func report_damage(receiver:Node2D)->void:
	hit_list.append(receiver)
	damage_received.emit(self)

func initialize_new()->DamageResource:
	var data:DamageResource = self.duplicate()
	data.damage_received.connect(on_damage_received)
	# create unique array
	hit_list = []
	return data

func initialize_split()->DamageResource:
	var data:DamageResource = self.duplicate()
	data.damage_received.connect(on_damage_received)
	return data

## Mainly used for receiving information from duplicates
func on_damage_received(damage:DamageResource)->void:
	damage_received.emit(damage)
