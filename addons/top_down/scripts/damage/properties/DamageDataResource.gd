class_name DamageDataResource
extends TransmissionResource

@export_category("Weapon or User")

## Initial base damage value.
@export var base_damage:Array[DamageTypeResource]

## Probability of critical damage happening
@export var critical_chance:float = 0.3

## Critical damage multiplier
@export var critical_multiply:float = 1.5

## Status effects that can be applied to target
@export var status_list:Array[DamageStatusResource]

@export_category("Report")

## Exploiting that array is shared reference.
## it will collect from same generation hits.
## Allows to hit same target once.
@export var hit_list:Array

## Callback function to receive DamageResource that hit a target.
## Using export allows to duplicate and maintain reference.
@export var report_callback:Callable

## These are set at collision time

## Kickback given to damage target, manipulated in ProjectileSetup
## Set by projectile uppon hitting a target.
var kickback_strength:float

## Direction of dealth damage
## Set by projectile uppon hitting a target.
var direction:Vector2

## An information for a damage report.
## Set by damage application process.
var is_critical:bool

## pre-calculated value
## Set by damage application process.
var total_damage:float


## Create a new generation for a new attack action.
## Do it from root DamageDataResource to copy initial exported values.
func new_generation()->DamageDataResource:
	var data:DamageDataResource = self.duplicate()
	data.transmission_name = "damage"
	#data.resource_name += "_gen"
	
	# create unique array
	data.hit_list = []
	return data

## Create new split of the same generation, like shrapnels from a granade explosion.
func new_split()->DamageDataResource:
	var data:DamageDataResource = self.duplicate()
	#data.resource_name += "_split"
	return data

## Receiving end should trigger this function
func process(resource_node:ResourceNode)->void:
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	if _damage_resource == null:
		failed()
		return
	if _damage_resource.can_receive_damage == false:
		try_again()
		return
	
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if _health_resource.is_dead:
		denied()
		return
	assert(_health_resource.hp > 0)
	
	# It's sure to have a hit, so pull last possible updates, like hit direction
	update_requested.emit()
	
	# TODO: include more receiving end information & proper way to get an owner reference
	hit_list.append(resource_node.owner)
	
	var _push_resource:PushResource = resource_node.get_resource("push")
	if _push_resource != null:
		_push_resource.add_impulse(direction * kickback_strength)
	
	success()
	
	for _damage:DamageTypeResource in base_damage:
		total_damage += _damage.value
		## TODO: Process dealt damage based on type and resistance
	
	_health_resource.add_hp( -total_damage )
	
	_damage_resource.receive(self)
	
	if report_callback.is_valid():
		report_callback.call(self)