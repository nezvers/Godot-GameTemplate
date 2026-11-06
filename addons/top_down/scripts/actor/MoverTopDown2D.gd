class_name MoverTopDown2D
extends ShapeCast2D

## Way to disable functionality at _ready
@export var enabled_process:bool = true

## Node that is moved and other Actors collide against
@export var character:CharacterBody2D

@export var collision_shape:CollisionShape2D

@export var max_collisions:int = 4

## Most an overlapping body gets pushed out per physics frame
@export var max_separation_step:float = 0.5

## Used for faking angled perspective movement
@export var axis_multiplier_resource:Vector2Resource

@export var resource_node:ResourceNode

@export var debug:bool

const MAX_SLIDES:int = 4

## Virtual buttons to react to
var input_resource:InputResource

## Stats for movement
var actor_stats_resource:ActorStatsResource

var velocity:Vector2

var axis_compensation:Vector2

var shape_rect:Rect2

## Bodies inside this one: physics ignores them (its recovery would pop them out at once) until soft separation gets them apart
var overlapping_bodies:Array[CharacterBody2D]

## Way to disable functionality during the gameplay
func set_enabled_process(value:bool)->void:
	enabled_process = value
	set_physics_process(enabled_process)

func _ready()->void:
	# Disable default ShapeCast2D
	enabled = false
	input_resource = resource_node.get_resource("input")
	assert(input_resource != null)
	
	actor_stats_resource = resource_node.get_resource("movement")
	assert(actor_stats_resource != null)
	
	var _push_resource = resource_node.get_resource("push")
	assert(_push_resource != null)
	_push_resource.impulse_event.connect(add_impulse)
	
	set_enabled_process(enabled_process)
	
	shape = collision_shape.shape
	shape_rect = shape.get_rect()
	shape_rect.size *= 0.5
	position = collision_shape.position
	collision_mask = character.collision_mask
	target_position = Vector2.ZERO
	axis_compensation = Vector2.ONE / axis_multiplier_resource.value
	_sync_physics_transform()
	_clear_overlapping()
	_remove_overlap()
	
	# in case used with PoolNode
	request_ready()
	velocity = Vector2.ZERO
	tree_exiting.connect(_push_resource.impulse_event.disconnect.bind(add_impulse), CONNECT_ONE_SHOT)
	# pooled bodies keep physics exceptions
	tree_exiting.connect(_clear_overlapping, CONNECT_ONE_SHOT)

## A pooled body re-enters with physics still at the spot it left, overlapping whatever stands there now.
## Kinematic bodies apply a new transform only on the next physics step, static ones at once.
func _sync_physics_transform()->void:
	var _rid:RID = character.get_rid()
	PhysicsServer2D.body_set_mode(_rid, PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_set_state(_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, character.global_transform)
	PhysicsServer2D.body_set_mode(_rid, PhysicsServer2D.BODY_MODE_KINEMATIC)

func _physics_process(delta:float)->void:
	_remove_overlap()
	
	var _target_velocity:Vector2 = actor_stats_resource.get_max_speed() * input_resource.axis
	velocity += get_impulse(velocity, _target_velocity, actor_stats_resource.get_acceleration(), delta)
	velocity *= axis_multiplier_resource.value
	move_and_slide(delta)
	velocity *= axis_compensation


## Adds an impulse to velocity, like a kickback
func add_impulse(impulse:Vector2)->void:
	velocity += impulse

## Calculate impulse Vector2 for delta time amount
func get_impulse(current_velocity:Vector2, target_velocity:Vector2, acceleration:float, delta:float)->Vector2:
	var _direction:Vector2 = target_velocity - current_velocity 
	var _distance:float = _direction.length()
	acceleration = delta * acceleration
	var _ratio:float = 0
	if _distance > 0.0:
		_ratio = min(acceleration / _distance, 1.0)
	return (_direction * _ratio)

func _remove_overlap()->void:
	force_shapecast_update()
	var _hit_solid:bool
	var _overlapping:Array[CharacterBody2D]
	for i:int in get_collision_count():
		var _collider:Object = get_collider(i)
		if _collider is CharacterBody2D:
			if _separate(_collider, get_collider_shape(i)):
				_overlapping.append(_collider)
			continue
		_hit_solid = true
	_update_overlapping(_overlapping)
	if _hit_solid:
		# physics recovery pushes out along the real contact normal
		character.move_and_collide(Vector2.ZERO)

## Soft push of an overlapping body along the axis of least penetration.
## Each side pushes the other half way, capped per frame so a pack spreads out instead of popping.
## Returns false when the bodies only touch.
func _separate(other:CharacterBody2D, shape_index:int)->bool:
	var _owner_id:int = other.shape_find_owner(shape_index)
	var _owner_node:Node2D = other.shape_owner_get_owner(_owner_id)
	var _other_extent:Vector2 = other.shape_owner_get_shape(_owner_id, 0).get_rect().size * 0.5
	var _distance:Vector2 = _owner_node.global_position - global_position
	var _overlap:Vector2 = shape_rect.size + _other_extent - _distance.abs()
	# touching is not overlapping
	if _overlap.x <= 0.0 || _overlap.y <= 0.0:
		return false
	var _push:Vector2
	if _overlap.x < _overlap.y:
		_push.x = _side(_distance.x, other) * _overlap.x
	else:
		_push.y = _side(_distance.y, other) * _overlap.y
	if !overlapping_bodies.has(other):
		overlapping_bodies.append(other)
		# both ways, either one can be the one moving
		character.add_collision_exception_with(other)
		other.add_collision_exception_with(character)
	_move_character(other, (_push * 0.5).limit_length(max_separation_step))
	return true

## Physics collides again with bodies that got apart
func _update_overlapping(current:Array[CharacterBody2D])->void:
	for i:int in range(overlapping_bodies.size() - 1, -1, -1):
		var _body:CharacterBody2D = overlapping_bodies[i]
		if current.has(_body):
			continue
		overlapping_bodies.remove_at(i)
		if is_instance_valid(_body):
			character.remove_collision_exception_with(_body)
			_body.remove_collision_exception_with(character)

func _clear_overlapping()->void:
	_update_overlapping([])

## Push direction on one axis, bodies on the same spot agree by instance id
func _side(distance:float, other:Object)->float:
	if distance != 0.0:
		return signf(distance)
	return 1.0 if character.get_instance_id() < other.get_instance_id() else -1.0

func _move_character(inst:CharacterBody2D, distance:Vector2)->void:
	inst.move_and_collide(distance)

func move_and_slide(delta:float)->void:
	var _motion:Vector2 = velocity * delta
	
	for _iteration:int in MAX_SLIDES:
		var _collision:KinematicCollision2D = character.move_and_collide(_motion) #maybe recovery info too
		if _collision == null:
			break
		if _collision != null:
			var _normal:Vector2 = (_collision.get_normal() * axis_multiplier_resource.value).normalized()
			
			_motion = (_collision.get_remainder() * axis_compensation).slide(_normal) * axis_multiplier_resource.value
			velocity = (velocity * axis_compensation).slide(_normal) * axis_multiplier_resource.value
