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
@export var damage_data_resource:DamageDataResource

## Create a new generation of damage data
## Best for splitting from top resource
@export var new_damage:bool = false

## Above 0: lobbed (LERP_TIME) projectiles land on the aimed point, at most this far.
## Mouse aim lands on the cursor, stick aim at full range.
@export var lob_range:float = 0.0

## A variable, not a const: property reads on a const resource are folded at compile time
var action_resource:ActionResource = preload("res://addons/top_down/resources/global_resources/action_resource.tres")

## Weapon this spawner belongs to, found once by walking up the tree
var _weapon:Weapon


func spawn()->void:
	assert(projectile_instance_resource != null)
	assert(axis_multiplication_resource != null)
	
	if !enabled:
		return
	prepare_spawn.emit()
	
	var new_damage_resource:DamageDataResource
	if new_damage:
		new_damage_resource = damage_data_resource.new_generation()
	else:
		new_damage_resource = damage_data_resource
	# shooter's outgoing multiplier (blood puddle), applied per split so it never compounds
	var _source_multiply:float = _source_damage_multiply()
	var _destination:Vector2 = _lob_destination() if lob_range > 0.0 else Vector2.ZERO
	
	for angle:float in projectile_angles:
		var _config_callback:Callable = func (inst:Projectile2D)->void:
			# TODO: maybe there's better solution
			var _angle_delta:Vector2 = (direction.rotated(deg_to_rad(angle)) - direction) * axis_multiplication_resource.value
			
			inst.direction = (direction + _angle_delta).normalized()
			inst.damage_data_resource = new_damage_resource.new_split()
			inst.damage_data_resource.upgrade_multiply *= _source_multiply
			inst.collision_mask = Bitwise.append_flags(inst.collision_mask, collision_mask)
			inst.global_position = initial_distance * direction * axis_multiplication_resource.value + projectile_position
			if lob_range > 0.0:
				inst.destination = _destination
		
		var _inst:Projectile2D = projectile_instance_resource.instance(_config_callback)

## Shooter's ActorStatsResource.get_damage_multiply(), 1.0 without a weapon owner.
## Looked up per spawn: pooled actors get new resources on every reuse.
func _source_damage_multiply()->float:
	if _find_weapon() == null || _weapon.resource_node == null:
		return 1.0
	var _stats:ActorStatsResource = _weapon.resource_node.get_resource("movement") as ActorStatsResource
	return 1.0 if _stats == null else _stats.get_damage_multiply()

func _lob_destination()->Vector2:
	var _offset:Vector2 = direction * lob_range * axis_multiplication_resource.value
	if action_resource.mouse_aim && _find_weapon() != null:
		_offset = (_weapon.get_global_mouse_position() - projectile_position).limit_length(lob_range)
	return projectile_position + _offset

func _find_weapon()->Weapon:
	if _weapon == null:
		var _node:Node = get_parent()
		while _node != null && !(_node is Weapon):
			_node = _node.get_parent()
		_weapon = _node
	return _weapon
