class_name DamageResource
extends TransmissionResource

## Initial base damage value 
@export var value:float = 1

## Critical damage multiplier
@export var critical_multiply:float = 1.5

## Probability of critical damage happening
@export var critical_chance:float = 0.3

## Probability of status effect happening
@export var status_chance:float = 0.3

## Direction of dealth damage
@export var direction:Vector2

## An information for a damage report
@export var is_critical:bool = false

## Exploiting that array is shared reference
## it will collect all same generation hits
@export var hit_list:Array

## pre-calculated value
@export var total_damage:float

## Projectile damage multiplier, manipulated in ProjectileSetup
@export var projectile_multiply:float = 1.0

## Kickback given to damage target, manipulated in ProjectileSetup
@export var kickback_strength:float

## Callback function to receive DamageResource that hit a target
@export var report_callback:Callable

## Example of status effect ticks
@export var bleed_status_ticks:int
@export var status_tick_interval:float = 0.5


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

## Create a new generation for a new attack action.
## Do it from root DamageResource
func new_generation()->DamageResource:
	var data:DamageResource = self.duplicate()
	data.resource_name += "_gen"
	data.initialize_generation()
	# create unique array
	data.hit_list = []
	return data

## Create new splitsh of the same generation, like shrapnels from a granade
func new_split()->DamageResource:
	var data:DamageResource = self.duplicate()
	data.resource_name += "_split"
	return data


## Receiving end should trigger this function
func process(resource_node:ResourceNode)->void:
	var _receive_damage_bool:BoolResource = resource_node.get_resource("receive_damage")
	if _receive_damage_bool == null:
		failed()
		return
	if _receive_damage_bool.value == false:
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
	
	if report_callback.is_valid():
		report_callback.call(self)
	
	
	_health_resource.add_hp( -get_total_damage() )
	# TODO: need a dedicated receiver data exchange
	# Used for showing received damage points
	_health_resource.damage_data.emit(self)
	
	if randf() > status_chance:
		return
	status_tick(bleed_status_ticks, resource_node, _health_resource)

func status_tick(remaining_count:int, resource_node:ResourceNode, health_resource:HealthResource)->void:
	if remaining_count < 1:
		return
	if health_resource.is_dead:
		return
	health_resource.add_hp( -get_total_damage() )
	health_resource.damage_data.emit(self)
	
	if remaining_count == 1:
		return
	var _tween:Tween = resource_node.create_tween()
	_tween.tween_callback(status_tick.bind(remaining_count -1, resource_node, health_resource)).set_delay(status_tick_interval)
