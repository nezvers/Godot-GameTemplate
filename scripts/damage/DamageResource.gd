class_name DamageResource
extends Resource

## receives damage_resource instance that reports damage
signal damage_report(damage:DamageResource)


@export var value:float = 1
@export var projectile_multiply:float = 1.0
@export var critical_multiply:float = 1.5
@export var critical_chance:float = 0.3
@export var direction:Vector2
@export var kickback_strength:float

## An information for a damage report
@export var is_critical:bool = false
## Exploiting that array is shared reference
## it will collect all same generation hits
@export var hit_list:Array
## pre-calculated value
@export var total_damage:float
## TODO: include information from source character

## final value applied in HealthResource
## Projectiles can influence resulting value
func get_total_damage()->float:
	return total_damage * projectile_multiply

## Cache the calculation at the begining
## Can be done for each split if necessary
func initialize_generation()->void:
	# TODO: insert your open world MMO RPG damage calculation here
	is_critical = randf() < critical_chance
	if is_critical:
		total_damage = value * critical_multiply
	else:
		total_damage = value

## Receiving end should trigger this function
## TODO: include more receiving end information
func report_damage_data(receiver:Node2D)->void:
	hit_list.append(receiver)
	damage_report.emit(self)

## Create a new generation for a new attack action.
## Do it from root DamageResource
func new_generation()->DamageResource:
	var data:DamageResource = self.duplicate()
	data.damage_report.connect(on_damage_report)
	data.initialize_generation()
	# create unique array
	data.hit_list = []
	return data

## Create new splitsh of the same generation, like shrapnels from a granade
func new_split()->DamageResource:
	var data:DamageResource = self.duplicate()
	data.damage_report.connect(on_damage_report)
	return data

## Mainly used for receiving information from duplicates
func on_damage_report(damage:DamageResource)->void:
	damage_report.emit(damage)
