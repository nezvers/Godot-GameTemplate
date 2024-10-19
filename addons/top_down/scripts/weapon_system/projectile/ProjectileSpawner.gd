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
## Scene from which a new projectile will be created
@export var projectile_scene:PackedScene
## Will be set for a new projectile
@export_flags_2d_physics var collision_mask:int
## Reference to projectile parent
@export var projectile_parent_reference:ReferenceNodeResource
## Angle offsets for each projectiles
## No angle, no projectile
## Use prepare_spawn signal to manipulate spread
@export var projectile_angles:Array[float] = [0.0]
## Resource that carry damage information
@export var damage_resource:DamageResource
## Create a new generation of damage data
## Best for splitting from top resource
@export var new_damage:bool = false


func spawn()->void:
	if !enabled:
		return
	assert(projectile_scene != null, "no projectile scene assigned")
	assert(projectile_parent_reference.node != null, "projectile parent reference isn't set")
	
	prepare_spawn.emit()
	
	var new_damage_resource:DamageResource
	if new_damage:
		new_damage_resource = damage_resource.new_generation()
	else:
		new_damage_resource = damage_resource
	
	for angle:float in projectile_angles:
		var inst:Projectile2D = projectile_scene.instantiate()
		#var axis_compensate:Vector2 = inst.axis_multiplier / Vector2.ONE
		inst.direction = direction.normalized().rotated(deg_to_rad(angle))
		inst.damage_resource = new_damage_resource.new_split()
		inst.collision_mask = Bitwise.append_flags(inst.collision_mask, collision_mask)
		inst.global_position = initial_distance * direction * axis_multiplication_resource.value + projectile_position
		projectile_parent_reference.node.add_child(inst)
