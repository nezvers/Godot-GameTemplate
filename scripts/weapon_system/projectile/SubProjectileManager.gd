class_name SubProjectileManager
extends Node

@export var projectile:Projectile2D
@export var projectile_spawner:ProjectileSpawner
## Scene created and the ready()
@export var start_projectile_scene:PackedScene
@export var exit_projectile_scene:PackedScene

func _ready()->void:
	# TODO: just a mockup. Need some kind per situation configurations
	projectile_spawner.collision_mask = Bitwise.append_flags(projectile_spawner.collision_mask, projectile.collision_mask)
	projectile_spawner.axis_multiplication = projectile.axis_multiplier
	
	if start_projectile_scene != null:
		spawn.call_deferred(start_projectile_scene)
	
	if exit_projectile_scene != null:
		projectile.tree_exiting.connect(spawn.bind(start_projectile_scene))

## Sets up projectile spawner and call spawns
func spawn(scene:PackedScene)->void:
	projectile_spawner.projectile_scene = scene
	projectile_spawner.projectile_position = projectile.global_position
	projectile_spawner.direction = projectile.direction
	projectile_spawner.damage_resource = projectile.damage_resource
	projectile_spawner.spawn()
