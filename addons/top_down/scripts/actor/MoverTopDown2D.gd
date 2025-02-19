class_name MoverTopDown2D
extends ShapeCast2D

## Way to disable functionality at _ready
@export var enabled_process:bool = true

## Node that is moved and other Actors collide against
@export var character:CharacterBody2D

@export var collision_shape:CollisionShape2D

@export var max_collisions:int = 4

## Used for faking angled perspective movement
@export var axis_multiplier_resource:Vector2Resource

@export var resource_node:ResourceNode

@export var debug:bool


## Virtual buttons to react to
var input_resource:InputResource

## Stats for movement
var actor_stats_resource:ActorStatsResource

var velocity:Vector2

var axis_compensation:Vector2

var shape_rect:Rect2

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
	_remove_overlap()
	
	# in case used with PoolNode
	request_ready()
	velocity = Vector2.ZERO
	tree_exiting.connect(_push_resource.impulse_event.disconnect.bind(add_impulse), CONNECT_ONE_SHOT)

func _physics_process(delta:float)->void:
	_remove_overlap()
	
	var _target_velocity:Vector2 = actor_stats_resource.max_speed * input_resource.axis
	velocity += get_impulse(velocity, _target_velocity, actor_stats_resource.acceleration, delta)
	velocity *= axis_multiplier_resource.value
	character.global_position += velocity * delta
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
	if !is_colliding():
		return
	var _solid_distance:Vector2
	var _solid_count:int
	for i:int in get_collision_count():
		var _point:Vector2 = get_collision_point(i)
		var _collider:Object = get_collider(i)
		if _collider is CharacterBody2D:
			var _distance:Vector2 = _point - global_position
			var _character_distance:Vector2 = _collider.global_position - global_position
			if _character_distance.length_squared() > _distance.length_squared():
				_move_character(_collider, _rect_distance(_distance))
			else:
				_move_character(_collider, _distance * 2)
			continue
		_solid_count += 1
		var _distance:Vector2 = global_position - _point
		_solid_distance += _rect_distance(_distance)
	if _solid_count > 0:
		_move_character(character, _solid_distance)
	# TODO: solve with move?

func _rect_distance(distance:Vector2)->Vector2:
	distance.x = sign(distance.x) * shape_rect.size.x - distance.x
	distance.y = sign(distance.y) * shape_rect.size.y - distance.y
	return distance

func _move_character(inst:CharacterBody2D, distance:Vector2)->void:
	inst.move_and_collide(distance)
