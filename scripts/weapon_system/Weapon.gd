class_name Weapon
extends Node2D


signal projectile_created
## signal before spawning for components prepare angle array
signal prepare_spawn

## Toggle weapons capability to spawn projectile
@export var enabled:bool = true
@export var projectile_scene:PackedScene
## Gun will set projectile collision_mask with this value
@export_flags_2d_physics var collision_mask:int
## Projectile spawn distance relative to this gun in pointed direction
@export var spawn_distance:float = 8.0
## Used for extra calculation to simulate angled top-down perspective
@export var axis_multiplication:Vector2 = Vector2.ONE
## Direction the projectile will be spawned
## Sound of shooling projectile
@export var sound_resource:SoundResource
## Reference to mover to access input resource
@export var mover:MoverTopDown2D
## Reference to projectile parent
@export var projectile_parent_reference:ReferenceNodeResource
## Angle offsets for each projectiles
## No angle, no projectile
## Use prepare_spawn signal to manipulate spread
@export var projectile_angles:Array[float] = [0.0]


func _ready()->void:
	set_enabled(enabled)

## Toggle connections to the action input and controls visibility
func set_enabled(value:bool)->void:
	enabled = value
	visible = enabled
	if enabled:
		if !mover.input_resource.action_pressed.is_connected(spawn_projectile):
			mover.input_resource.action_pressed.connect(spawn_projectile)
	else:
		if mover.input_resource.action_pressed.is_connected(spawn_projectile):
			mover.input_resource.action_pressed.disconnect(spawn_projectile)


func spawn_projectile()->void:
	if !enabled:
		return
	assert(projectile_scene != null, "no projectile scene assigned")
	assert(projectile_parent_reference.node != null, "projectile parent reference isn't set")
	
	prepare_spawn.emit()
	for angle:float in projectile_angles:
		var direction:Vector2 = mover.input_resource.aim_direction.rotated(deg_to_rad(angle))
		var inst:Projectile2D = projectile_scene.instantiate()
		inst.direction = direction
		inst.collision_mask = Bitwise.append_flags(inst.collision_mask, collision_mask)
		projectile_parent_reference.node.add_child(inst)
		inst.global_position = spawn_distance * direction * axis_multiplication + global_position
		
	
	sound_resource.play_managed()
	projectile_created.emit()
