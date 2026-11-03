## Counter for collectables: coins (also the score), meat, slime, boss crystals.
class_name ScoreResource
extends SaveableResource

signal updated

@export var value:int = 0

## Everything collected since the last reset; spending never lowers it.
@export var collected_total:int = 0

## Writes the save file on every change (meta-progress counters).
@export var save_on_change:bool = false

func reset_resource()->void:
	value = 0
	collected_total = 0
	updated.emit()

func prepare_load(data:Resource)->void:
	value = data.value
	collected_total = data.collected_total
	updated.emit()

func add_point()->void:
	add(1)

func add(amount:int = 1)->void:
	value += amount
	collected_total += amount
	_changed()

## Gives back spent value without counting it as collected again.
func refund(amount:int)->void:
	value += amount
	_changed()

func can_spend(amount:int)->bool:
	return value >= amount

## Returns false and changes nothing when there isn't enough.
func spend(amount:int)->bool:
	if !can_spend(amount):
		return false
	value -= amount
	_changed()
	return true

func _changed()->void:
	updated.emit()
	if save_on_change:
		save_resource()
