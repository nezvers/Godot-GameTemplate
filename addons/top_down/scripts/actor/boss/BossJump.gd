## Jumps at the target: the landing spot is marked during windup (CIRCLE telegraph), landing damages and pushes around it.
## Below burst_health a jump can be a burst instead: the body pops on landing, killing itself (SlimeSplit releases children).
class_name BossJump
extends BossAttack

@export var character:CharacterBody2D

@export var resource_node:ResourceNode

@export var jump_move:JumpMove

## Disabled while airborne, JumpMove moves the body
@export var mover:MoverTopDown2D

@export var area_receiver:AreaReceiver2D

@export var axis_multiplication:Vector2Resource

@export var damage_transmitter:ShapeCastTransmitter2D

## Push without damage, also moves other enemies away
@export var push_transmitter:ShapeCastTransmitter2D

@export var push_channel_transmitter:DataChannelTransmitter

## Landing spot is the target position clamped to this distance (perspective compensated)
@export var max_jump_distance:float = 64.0

@export var jump_time:float = 0.7

## Can't be hit while in the air
@export var airborne_invulnerable:bool = false

## Body collides only with these while airborne, jumps over other enemies
@export_flags_2d_physics var jump_collision_mask:int = 1

@export var kickback_radius:float = 32.0

@export var kickback_max:float = 140.0

@export var kickback_min:float = 40.0

@export var vfx:InstanceResource

@export var sound:SoundResource

@export var camera_shake:CameraShakeResource

## Health ratio at or below which a jump can be a burst
@export_range(0.0, 1.0) var burst_health:float = 0.5

## Chance of a jump being a burst while below burst_health
@export_range(0.0, 1.0) var burst_chance:float = 0.35

## Telegraph and landing areas are scaled by this for a burst
@export var burst_area_scale:float = 1.3

@export var burst_color:Color = Color(1.0, 0.1, 0.05, 0.45)

var landing_position:Vector2
## Jump direction in global space
var global_direction:Vector2
var is_burst:bool
var is_jumping:bool
## Changes when a jump is cancelled, a stale perform() must not land
var jump_id:int
var health_resource:HealthResource
var receiver_collision_layer:int
var saved_collision_mask:int
var axis_compensation:Vector2
var telegraph_color:Color
var telegraph_radius:float
var damage_scale:Vector2
var push_scale:Vector2
var has_base_sizes:bool

func _ready()->void:
	health_resource = resource_node.get_resource("health")
	receiver_collision_layer = area_receiver.collision_layer
	axis_compensation = Vector2.ONE / axis_multiplication.value
	# authored sizes, read once: a pooled bloater that burst comes back with burst sizes
	if !has_base_sizes:
		has_base_sizes = true
		damage_scale = damage_transmitter.scale
		push_scale = push_transmitter.scale
		if telegraph != null:
			telegraph_color = telegraph.color
			telegraph_radius = telegraph.radius
	if !push_channel_transmitter.update_requested.is_connected(_update_push):
		push_channel_transmitter.update_requested.connect(_update_push)
	# in case used with PoolNode, ResourceNode makes new resources on every ready
	request_ready()

func prepare(new_target:Node2D)->void:
	super.prepare(new_target)
	var _difference:Vector2 = (target.global_position - character.global_position) * axis_compensation
	if _difference.length_squared() < 1.0:
		_difference = Vector2.RIGHT
	var _direction:Vector2 = _difference.normalized()
	landing_position = character.global_position + _direction * minf(_difference.length(), max_jump_distance) * axis_multiplication.value
	global_direction = (_direction * axis_multiplication.value).normalized()

	var _health_ratio:float = health_resource.hp / maxf(health_resource.max_hp, 1.0)
	is_burst = _health_ratio <= burst_health && randf() < burst_chance
	var _area_scale:float = burst_area_scale if is_burst else 1.0
	damage_transmitter.scale = damage_scale * _area_scale
	push_transmitter.scale = push_scale * _area_scale
	if telegraph != null:
		telegraph.top_level = true
		telegraph.global_position = landing_position
		telegraph.color = burst_color if is_burst else telegraph_color
		telegraph.radius = telegraph_radius * _area_scale

func perform()->void:
	if !running:
		return
	jump_id += 1
	var _id:int = jump_id
	is_jumping = true
	saved_collision_mask = character.collision_mask
	character.collision_mask = jump_collision_mask
	mover.set_enabled_process(false)
	if airborne_invulnerable:
		area_receiver.collision_layer = 0

	jump_move.move_target_position(landing_position, jump_time)
	await jump_move.jump_finished
	if _id != jump_id || !is_jumping:
		return
	_end_jump()

	damage_transmitter.check_transmission()
	push_transmitter.check_transmission()
	var _pos:Vector2 = character.global_position
	if vfx != null:
		vfx.instance(func (inst:Node2D)->void: inst.global_position = _pos)
	if sound != null:
		sound.play_managed()
	if camera_shake != null:
		camera_shake.play()
	if is_burst:
		_burst()

func stop()->void:
	super.stop()
	if is_jumping:
		jump_id += 1
		jump_move.cancel()
		_end_jump()

func _end_jump()->void:
	is_jumping = false
	character.collision_mask = saved_collision_mask
	mover.set_enabled_process(true)
	area_receiver.collision_layer = receiver_collision_layer

## Same death as HoleDeath, a killing DamageDataResource lets SlimeSplit spawn the children
func _burst()->void:
	if health_resource.is_dead:
		return
	var _hp:float = health_resource.hp
	health_resource.insta_kill()
	var _damage_data:DamageDataResource = DamageDataResource.new("damage")
	_damage_data.total_damage = _hp
	_damage_data.is_kill = true
	# children spread around the jump direction
	_damage_data.direction = global_direction
	var _damage:DamageResource = resource_node.get_resource("damage")
	_damage.receive(_damage_data)

## Closer is pushed harder
func _update_push(damage_data:DamageDataResource, receiver:AreaReceiver2D)->void:
	var _distance:Vector2 = receiver.global_position - push_transmitter.global_position
	var _distance_length:float = (_distance * axis_compensation).length()
	var _t:float = minf(_distance_length / kickback_radius, 1.0)
	damage_data.kickback_strength = lerpf(kickback_max, kickback_min, _t)
	damage_data.direction = _distance.normalized() if _distance_length > 2.0 else global_direction
