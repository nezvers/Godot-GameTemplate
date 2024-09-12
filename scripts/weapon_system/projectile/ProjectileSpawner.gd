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
## offset distance in the direction
@export var initial_distance:float
## Scene from which a new projectile will be created
@export var projectile_scene:PackedScene
## Will be set for a new projectile
@export_flags_2d_physics var collision_mask:int
## Movement modifier to fake angled perspective
@export var axis_multiplication:Vector2 = Vector2(1.0, 0.5)
## Reference to projectile parent
@export var projectile_parent_reference:ReferenceNodeResource
## Angle offsets for each projectiles
## No angle, no projectile
## Use prepare_spawn signal to manipulate spread
@export var projectile_angles:Array[float] = [0.0]
## Resource that carry damage information
@export var damage_resource:DamageResource


func spawn()->void:
	if !enabled:
		return
	assert(projectile_scene != null, "no projectile scene assigned")
	assert(projectile_parent_reference.node != null, "projectile parent reference isn't set")
	
	prepare_spawn.emit()
	var new_damage_resource:DamageResource = damage_resource.new_split()
	for angle:float in projectile_angles:
		var inst:Projectile2D = projectile_scene.instantiate()
		inst.direction = direction.normalized()
		inst.damage_resource = new_damage_resource
		inst.collision_mask = Bitwise.append_flags(inst.collision_mask, collision_mask)
		inst.global_position = initial_distance * direction * axis_multiplication + projectile_position
		projectile_parent_reference.node.add_child(inst)
