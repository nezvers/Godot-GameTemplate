class_name SubProjectileManager
extends Node

@export var projectile:Projectile2D
@export var projectile_spawner:ProjectileSpawner
@export var start_projectile_instance_resource:InstanceResource
@export var end_projectile_instance_resource:InstanceResource
## Used for extra calculation to simulate angled top-down perspective
@export var axis_multiplication_resource:Vector2Resource

var axis_compensation:Vector2

func _ready()->void:
	# TODO: just a mockup. Need some kind per situation configurations
	projectile_spawner.collision_mask = Bitwise.append_flags(projectile_spawner.collision_mask, projectile.collision_mask)
	axis_compensation = Vector2.ONE / axis_multiplication_resource.value
	
	if start_projectile_instance_resource != null:
		spawn(start_projectile_instance_resource)
	
	if end_projectile_instance_resource != null:
		projectile.tree_exiting.connect(spawn.bind(end_projectile_instance_resource))

## Sets up projectile spawner and call spawns
func spawn(projectile_instance_resource:InstanceResource)->void:
	projectile_spawner.projectile_instance_resource = projectile_instance_resource
	projectile_spawner.projectile_position = projectile.global_position
	projectile_spawner.direction = projectile.direction
	projectile_spawner.damage_resource = projectile.damage_resource
	projectile_spawner.spawn()
