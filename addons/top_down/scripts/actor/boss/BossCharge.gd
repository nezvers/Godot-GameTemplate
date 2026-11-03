## Direction is locked when windup starts (telegraph line), then the boss rushes straight.
## Hits the target once on contact. Running into a wall stuns the boss: a long punish window.
class_name BossCharge
extends BossAttack

@export var character:CharacterBody2D

@export var resource_node:ResourceNode

@export var axis_multiplication:Vector2Resource

@export var speed:float = 200.0

@export var acceleration:float = 1500.0

@export var duration:float = 0.9

## Contact damage during the charge
@export var damage_transmitter:ShapeCastTransmitter2D

@export var damage_channel_transmitter:DataChannelTransmitter

@export var kickback:float = 180.0

## Added to recovery when charge is stopped by a wall
@export var wall_stun:float = 1.6

@export var wall_vfx:InstanceResource

@export var wall_sound:SoundResource

@export var camera_shake:CameraShakeResource

## Body collides only with these while charging, other enemies get pushed aside instead of blocking
@export_flags_2d_physics var charge_collision_mask:int = 1

## Input axis direction (compensated for perspective)
var direction:Vector2
## Same direction in global space
var global_direction:Vector2
var input_resource:InputResource
var stats_resource:ActorStatsResource
var saved_speed:float
var saved_acceleration:float
var saved_collision_mask:int
var is_charging:bool
var has_hit:bool

func _ready()->void:
	input_resource = resource_node.get_resource("input")
	stats_resource = resource_node.get_resource("movement")
	if !damage_channel_transmitter.update_requested.is_connected(_update_damage):
		damage_channel_transmitter.update_requested.connect(_update_damage)
	if !damage_channel_transmitter.success.is_connected(_on_hit):
		damage_channel_transmitter.success.connect(_on_hit)
	# in case used with PoolNode, ResourceNode makes new resources on every ready
	request_ready()

func prepare(new_target:Node2D)->void:
	super.prepare(new_target)
	var _difference:Vector2 = target.global_position - character.global_position
	if _difference.length_squared() < 1.0:
		_difference = Vector2.RIGHT
	direction = (_difference / axis_multiplication.value).normalized()
	global_direction = (direction * axis_multiplication.value).normalized()
	if telegraph != null:
		telegraph.vector = direction * axis_multiplication.value * speed * duration

func perform()->void:
	if !running:
		return
	is_charging = true
	has_hit = false
	saved_speed = stats_resource.max_speed
	saved_acceleration = stats_resource.acceleration
	stats_resource.max_speed = speed
	stats_resource.acceleration = acceleration
	saved_collision_mask = character.collision_mask
	character.collision_mask = charge_collision_mask

	var _elapsed:float = 0.0
	var _previous:Vector2 = character.global_position
	while _elapsed < duration:
		input_resource.set_axis(direction)
		await get_tree().physics_frame
		if !is_charging:
			return
		var _delta:float = get_physics_process_delta_time()
		_elapsed += _delta
		if !has_hit:
			damage_transmitter.check_transmission()
		var _moved:float = character.global_position.distance_to(_previous)
		_previous = character.global_position
		# after speeding up, barely moving means something blocks
		if _elapsed > 0.15 && _moved < speed * _delta * 0.25 && _is_wall_ahead():
			_wall_hit()
			break
	_end_charge()

func stop()->void:
	super.stop()
	_end_charge()

func _end_charge()->void:
	if !is_charging:
		return
	is_charging = false
	stats_resource.max_speed = saved_speed
	stats_resource.acceleration = saved_acceleration
	character.collision_mask = saved_collision_mask
	input_resource.set_axis(Vector2.ZERO)

func _is_wall_ahead()->bool:
	var _collision:KinematicCollision2D = character.move_and_collide(global_direction * 4.0, true)
	if _collision == null:
		return false
	return !(_collision.get_collider() is CharacterBody2D)

func _wall_hit()->void:
	extra_recovery = wall_stun
	var _pos:Vector2 = character.global_position
	if wall_vfx != null:
		wall_vfx.instance(func (inst:Node2D)->void: inst.global_position = _pos)
	if wall_sound != null:
		wall_sound.play_managed()
	if camera_shake != null:
		camera_shake.play()

func _on_hit()->void:
	has_hit = true

func _update_damage(damage_data:DamageDataResource, _receiver:AreaReceiver2D)->void:
	damage_data.direction = global_direction
	damage_data.kickback_strength = kickback
