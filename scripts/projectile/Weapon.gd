class_name Weapon
extends Node2D

signal projectile_created

## Toggle weapons capability to spawn projectile
@export var enabled:bool = true
@export var projectile_scene:PackedScene
@export var projectile_parent_path:String
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
@export var mover_2d:MoverTopDown2D

var projectile_parent:Node2D

func _ready()->void:
	projectile_parent = get_node(projectile_parent_path)
	if projectile_parent == null:
		printerr(name, " [ERROR]: projectile parent is invalid")
		return
	mover_2d.input_resource.action_pressed.connect(spawn_projectile)

func spawn_projectile()->void:
	if !enabled:
		return
	if projectile_scene == null:
		printerr(name, " [ERROR]: no projectile scene assigned")
		return
	if projectile_parent == null:
		printerr(name, " [ERROR]: projectile parent is null")
		return
	
	var direction:Vector2 = mover_2d.input_resource.aim_direction
	var inst:Projectile2D = projectile_scene.instantiate()
	inst.direction = direction
	inst.collision_mask = Bitwise.append_flags(inst.collision_mask, collision_mask)
	projectile_parent.add_child(inst)
	inst.global_position = spawn_distance * direction * axis_multiplication + global_position
	sound_resource.play_managed()
	projectile_created.emit()
