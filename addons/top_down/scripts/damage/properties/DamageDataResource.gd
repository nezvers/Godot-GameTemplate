class_name DamageDataResource
extends TransmissionResource

## Global setting; resources holding a reference get deep-duplicated with a stale mode.
const DIFFICULTY:DifficultyResource = preload("res://addons/top_down/resources/global_resources/difficulty_resource.tres")

@export_group("Weapon or User")

## Initial base damage value.
@export var base_damage:Array[DamageTypeResource]

## Probability of critical damage happening
@export_range(0.0, 1.0) var critical_chance:float = 0.3

## Critical damage multiplier
@export var critical_multiply:float = 1.5

## Status effects that can be applied to target
@export var status_list:Array[DamageStatusResource]

## Weapon upgrade bonus; exported so generations and splits carry it to projectiles.
@export var upgrade_multiply:float = 1.0

@export_group("Report")

## Exploiting that array is shared reference.
## it will collect from same generation hits.
## Allows to hit same target once.
@export var hit_list:Array

## Callback function to receive DamageResource that hit a target.
## Using export allows to duplicate and maintain reference.
@export var report_callback:Callable

## Kickback given to damage target, manipulated in ProjectileSetup
## Set by projectile uppon hitting a target.
@export var kickback_strength:float

## These are set at collision time

## Direction of dealth damage
## Set by projectile uppon hitting a target.
var direction:Vector2

## An information for a damage report.
## Set by damage application process.
var is_critical:bool

## A way to read if it was a killing damage
var is_kill:bool

## pre-calculated value
## Set by damage application process.
var total_damage:float

var damage_multiply:float = 1.0

func _init(_transmission_name:String = "")->void:
	transmission_name = _transmission_name

## Create a new generation for a new attack action.
## Do it from root DamageDataResource to copy initial exported values.
func new_generation()->DamageDataResource:
	var data:DamageDataResource = self.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	data.transmission_name = "damage"
	#data.resource_name += "_gen"
	
	# create unique array
	data.hit_list = []
	return data

## Create new split of the same generation, like shrapnels from a granade explosion.
func new_split()->DamageDataResource:
	var data:DamageDataResource = self.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	#data.resource_name += "_split"
	return data

## Receiving end should trigger this function
func process(resource_node:ResourceNode)->void:
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	if _damage_resource == null:
		failed()
		return
	if _damage_resource.can_receive_damage == false || _damage_resource.immune:
		try_again()
		return
	
	var _health_resource:HealthResource = resource_node.get_resource("health")
	# (0 hp without being dead: a co-op player lying downed, or a copy of one)
	if _health_resource.is_dead || _health_resource.hp <= 0.0:
		denied()
		return
	
	# It's sure to have a hit, so pull last possible updates, like hit direction
	update_requested.emit()
	
	hit_list.append(_damage_resource.owner)
	
	if _damage_resource.forward_hit.is_valid():
		_forward(_damage_resource)
		return
	
	var _push_resource:PushResource = resource_node.get_resource("push")
	if _push_resource != null:
		_push_resource.add_impulse(direction * kickback_strength)
	
	if !base_damage.is_empty():
		# Critical multiply
		if randf() < critical_chance:
			is_critical = true
			damage_multiply = critical_multiply
		
		# Dealt damage
		for _damage:DamageTypeResource in base_damage:
			total_damage += max(_damage.value * damage_multiply * upgrade_multiply - _damage_resource.resistance_value_list[_damage.type], 0.0)
		if _damage_resource.difficulty_scaled:
			total_damage *= DIFFICULTY.damage_multiplier()
	
		_health_resource.add_hp( -total_damage )
		is_kill = _health_resource.is_dead
		_damage_resource.receive(self)
	
	# Status effects have their own implementations
	for _status:DamageStatusResource in status_list:
		_status.process(resource_node, _damage_resource)
	
	if report_callback.is_valid():
		report_callback.call(self)
	
	success()

## A copy of an actor another machine owns: work out the damage, let the owner apply it.
func _forward(damage_resource:DamageResource)->void:
	if !base_damage.is_empty():
		if randf() < critical_chance:
			is_critical = true
			damage_multiply = critical_multiply
		for _damage:DamageTypeResource in base_damage:
			total_damage += max(_damage.value * damage_multiply * upgrade_multiply - damage_resource.resistance_value_list[_damage.type], 0.0)
		if damage_resource.difficulty_scaled:
			total_damage *= DIFFICULTY.damage_multiplier()
	if total_damage > 0.0 || kickback_strength > 0.0:
		damage_resource.forward_hit.call(self)
	if total_damage > 0.0:
		damage_resource.receive_points(total_damage, is_critical)
	if report_callback.is_valid():
		report_callback.call(self)
	success()
