class_name DamageResource
extends SaveableResource

signal report_damage(damage_data:DamageDataResource)
signal received_damage(damage_data:DamageDataResource)
signal received_damage_points(points:float, is_critical:bool)
signal store_status(status_effect:DamageStatusResource)

signal can_receive_changed

@export var can_receive_damage:bool = true

## Scale received damage by the difficulty's enemy_damage_ratio (player only).
@export var difficulty_scaled:bool

## Resistance value for each DamageType summed.
## Placed in an array for optimized value fetching.
## It is initialized and managed by DamageSetup Node.
var resistance_value_list:Array[float]

var owner:Node

## Co-op: set on copies of actors owned by another machine. A hit on them is
## measured as usual (crits, resistances) and handed to this callable with the
## DamageDataResource instead of being applied here (NetEntities sends it on).
var forward_hit:Callable

## Co-op: no hit lands while set (downed, waiting at a door, the dedicated
## server's hidden player). Separate from can_receive_damage, which the hit
## cooldown (DamageCooldown) switches back on by itself.
var immune:bool

## Co-op: called as (damage_resource, points, is_critical) on every received hit,
## so the host can show it on the other machines' copies (NetEntities).
static var points_hook:Callable


func set_can_receive_damage(value:bool)->void:
	can_receive_damage = value
	can_receive_changed.emit()

func report(damage_data:DamageDataResource)->void:
	report_damage.emit(damage_data)

func receive(damage_data:DamageDataResource)->void:
	received_damage.emit(damage_data)
	receive_points(damage_data.total_damage, damage_data.is_critical)

func receive_points(points:float, is_critical:bool = false)->void:
	received_damage_points.emit(points, is_critical)
	if points_hook.is_valid():
		points_hook.call(self, points, is_critical)

func add_status_effect(status_effect:DamageStatusResource)->void:
	store_status.emit(status_effect)
