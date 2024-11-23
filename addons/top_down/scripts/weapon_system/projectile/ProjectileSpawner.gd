## Handles spawning new projectiles
class_name ProjectileSpawner
extends Node

## signal before spawning for components prepare angle array
signal prepare_spawn

## If enabled is false then spawning will be cancelled
@export var enabled:bool = true

## global_position spawning point from which actual position will be calculated
@export var projectile_position:Vector2

## Scene that will be instantiated to create a projectile
## Direction a projectile will fly
@export var direction:Vector2

## Used for extra calculation to simulate angled top-down perspective
@export var axis_multiplication_resource:Vector2Resource

## offset distance in the direction
@export var initial_distance:float
@export var projectile_instance_resource:InstanceResource

## Will be set for a new projectile
@export_flags_2d_physics var collision_mask:int

## Angle offsets for each projectiles
## No angle, no projectile
## Use prepare_spawn signal to manipulate spread
@export var projectile_angles:Array[float] = [0.0]

## Resource that carry damage information
@export var damage_resource:DamageResource

## Create a new generation of damage data
## Best for splitting from top resource
@export var new_damage:bool = false

var axis_compensation:Vector2

func _ready()->void:
	axis_compensation = Vector2.ONE / axis_multiplication_resource.value

func spawn()->void:
	assert(projectile_instance_resource != null)
	assert(axis_multiplication_resource != null)
	
	if !enabled:
		return
	prepare_spawn.emit()
	
	var new_damage_resource:DamageResource
	if new_damage:
		new_damage_resource = damage_resource.new_generation()
	else:
		new_damage_resource = damage_resource
	
	for angle:float in projectile_angles:
		var _config_callback:Callable = func (inst:Projectile2D)->void:
			inst.direction = (direction.rotated(deg_to_rad(angle)) * axis_multiplication_resource.value).normalized()
			inst.damage_resource = new_damage_resource.new_split()
			inst.collision_mask = Bitwise.append_flags(inst.collision_mask, collision_mask)
			inst.global_position = initial_distance * direction * axis_multiplication_resource.value + projectile_position
		
		var _inst:Projectile2D = projectile_instance_resource.instance(_config_callback)
