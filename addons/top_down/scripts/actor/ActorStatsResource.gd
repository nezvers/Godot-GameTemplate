class_name ActorStatsResource
extends SaveableResource

@export var acceleration:float
@export var max_speed:float

## Speed multipliers from effects, keyed by source (e.g. "stuck", "slow")
var speed_multipliers:Dictionary

## Value 1.0 removes the multiplier
func set_speed_multiplier(key:StringName, value:float)->void:
	if value == 1.0:
		speed_multipliers.erase(key)
		return
	speed_multipliers[key] = value

## max_speed with all multipliers applied
func get_max_speed()->float:
	var _speed:float = max_speed
	for _value:float in speed_multipliers.values():
		_speed *= _value
	return _speed

## Acceleration multipliers from effects, keyed by source (e.g. "slippery").
## Acceleration also brakes, so a low value makes the actor slide.
var acceleration_multipliers:Dictionary

## Value 1.0 removes the multiplier
func set_acceleration_multiplier(key:StringName, value:float)->void:
	if value == 1.0:
		acceleration_multipliers.erase(key)
		return
	acceleration_multipliers[key] = value

## acceleration with all multipliers applied
func get_acceleration()->float:
	var _acceleration:float = acceleration
	for _value:float in acceleration_multipliers.values():
		_acceleration *= _value
	return _acceleration

## Outgoing damage multipliers from effects, keyed by source (e.g. "empowered")
var damage_multipliers:Dictionary

## Value 1.0 removes the multiplier
func set_damage_multiplier(key:StringName, value:float)->void:
	if value == 1.0:
		damage_multipliers.erase(key)
		return
	damage_multipliers[key] = value

## Product of all outgoing damage multipliers
func get_damage_multiply()->float:
	var _multiply:float = 1.0
	for _value:float in damage_multipliers.values():
		_multiply *= _value
	return _multiply
