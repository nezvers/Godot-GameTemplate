@tool
## Give high fidelity controls over a Node2D to give a behaviour like a RigidBody but better.
class_name RigidControler
extends Node2D

#* HOW TO DETECT OTHER?
# What is a root node?
# 	Could Node2D be used?
#		Perfectly the only dependency would be Shape2D and manipulate PhysicsServer directly
#		And be associated as shape's owner, then movement collision would give direct reference

#* PUSHING
# From bounce against other object need to know if other could move - objects status variable?
# What are conditions of no ability to move?
# 	Can't move in that direction
# 		Has a collision - test one step
# 	Too big mass to move
# 	Bool for movable
# How to parametrize conditions of no ability to move?
# 	Mass ratio and ratio multiplier
# 	Mass ratio treshold when it's movable
# Perfect elastic collision with conserved total energy (not counting dampening)

# What if other came at you too? (Precision simulation)
# 	Need to calculate meeting position & trade velocities

#* ELEVATORS AND SQUISHERS
# Not movable
# Single step iteration
# 	Maybe alternative function to move - transport?
# Need an ability to drag and push
# 	Pushing notifies other that it is squished because it couldn't move
#	Push only as far as possible
# Can give momentum impulse when stopped and/or continuously

#* JUMP PADS AND TRAMPOLINES/BOUNCE PADS
# Trampolines could work as additive/multiplier when acted against it
# 	if pusher don't have bounciness, still should be able to react and give extra energy back
# Jump pads should react when sliding over it
# 	Area2D could work for that

#* CUSTOM COLLISION
# One-way platforms
# Only affect others & not detected - only push
# 	Then only dependency would be Shape2D and CollisionShape could be spawned like ShapeCast
# 	Can Pusher make other to think it is standing on something in its own update?
#		Can a temporary collider be seen only to a specific other only?

#* TILE COLLISIONS
# What informations could be useful when colliding against TileMapLayer

#* CALLBACKS
# Try to get calls for hits from RigidBody, CharacterBody (Cool to have, not required)
# Call other to notify collision, ability to influence collision bi-directionaly
# 	Check if other moved onto you too
# 	Maybe testing meeting, collision didn't happen

## Physical layers body is detected
@export_flags_2d_physics var collision_layer:int
## Physical layers body is colliding against
@export_flags_2d_physics var collision_mask:int
## Node that be moved as with physical body
@export var move_body:Node2D
## Collision shape used as a physical representation of self
@export var shape:Shape2D : set = set_shape
## if it's possible to push it
@export var movable:bool = true
## Comparison value between bodies
@export var mass:float = 1.0
## Mass ratio when other body is not movable
@export var movable_treshold:float
## Blends between bounce and slide against a surface
@export_range(0.0, 1.0) var bounciness:float
## Minimal dot product value to blend between bounce
@export_range(0.01, 1.0) var slide_treshold:float
## Maximal movement itteration count from collisions
@export var max_steps:int = 10
## Can be used to create force loss for each bounce
@export_range(0.0, 1.0) var bounce_multiply:float = 1.0
## Can be used to create force loss for each slide
@export_range(0.0, 1.0) var slide_multiply:float = 1.0
## Color to visualy display body created for movement
@export var color:Color : set = set_color

## It is going to be used to calculate movement
var shape_cast:ShapeCast2D = ShapeCast2D.new()
## A way to show state of a last move
var move_solved:bool = true
## Reference to a physical body on PhysicsServer2D
var body_rid:RID

func set_shape(_shape:Shape2D)->void:
	shape = _shape
	queue_redraw()
	if shape == null:
		return
	if !shape.changed.is_connected(queue_redraw):
		shape.changed.connect(queue_redraw)

func set_color(value:Color)->void:
	color = value
	queue_redraw()

## Built-in drawing callback when drawing queue calls it
func _draw()->void:
	if shape == null || color.a < 0.01:
		return
	Drawer.draw_shape2d(self, shape, color)

func _ready()->void:
	if Engine.is_editor_hint():
		return
	_create_body()

## Initialize physical body setup
func _create_body()->void:
	body_rid = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_space(body_rid, get_world_2d().space)
	PhysicsServer2D.body_set_collision_layer(body_rid, collision_layer)
	PhysicsServer2D.body_set_collision_mask(body_rid, collision_mask)
	PhysicsServer2D.body_add_shape(body_rid, shape.get_rid(), move_body.global_transform)
	PhysicsServer2D.body_set_mode(body_rid, PhysicsServer2D.BODY_MODE_KINEMATIC)
	PhysicsServer2D.body_set_omit_force_integration(body_rid, true)
	PhysicsServer2D.body_attach_object_instance_id(body_rid, get_instance_id())
	
	# don't check collisions against self
	shape_cast.add_exception_rid(body_rid)
	shape_cast.shape = shape
	shape_cast.enabled = false
	shape_cast.collision_mask = collision_mask
	move_body.add_child.call_deferred(shape_cast)

## Movement controllers can call this to simulate movement for a Vector
func move(vector:Vector2)-> Vector2:
	for i:int in max_steps:
		if _step(vector):
			move_solved = true
			_move_shape(vector)
			return vector
		var _fraction:float = shape_cast.get_closest_collision_safe_fraction()
		var _moved:Vector2 = vector * _fraction
		_move_shape(_moved)
		vector = (vector - _moved)
		
		var _other:Node = shape_cast.get_collider(0)
		vector = _push(_other, vector)
		vector = _bounce_and_slide(vector)
	
	# All steps were used
	move_solved = false
	return vector

## Does a step check
## False means collision and shape_cast has the data
func _step(vector:Vector2)->bool:
	shape_cast.target_position = vector
	shape_cast.force_shapecast_update()
	return !shape_cast.is_colliding()

## update the root node and physics body
func _move_shape(vector:Vector2)->void:
	move_body.global_position += vector
	PhysicsServer2D.body_set_shape_transform(body_rid, 0, move_body.global_transform)

func _push(other:Node2D, vector:Vector2)-> Vector2:
	if other is RigidControler:
		return _push_rigid_controler(other, vector)
	return vector

func _bounce_and_slide(vector:Vector2)-> Vector2:
	assert(shape_cast.get_collision_count() > 0)
	var _normal:Vector2 = shape_cast.get_collision_normal(0)
	var _dot_product:float = _normal.dot(-vector.normalized())
	if _dot_product < slide_treshold:
		return vector.bounce(_normal) * bounce_multiply
	
	var _bounce = vector.bounce(_normal) * bounce_multiply
	var _slide = vector.slide(_normal) * slide_multiply
	return _slide.lerp(_bounce, bounciness)


func _push_rigid_controler(other:RigidControler, vector:Vector2)->Vector2:
	if !other.movable:
		return vector
	# if other mass is smaller - reduce & shoot other
	# if mass are equal - split oposit directions
	# if mass is bigger - mostly bounce back
	var _magnitude:float = vector.length()
	var _given_fraction:float = mass / (other.mass + mass)
	var _given_multiply:float = mass / other.mass
	var _given_magnitude:float = _given_fraction * _given_multiply * _magnitude
	var _normal:Vector2 = shape_cast.get_collision_normal(0)
	other.move(_given_fraction * _given_multiply * _given_magnitude * -_normal)
	
	# TODO: notify other to check if it has some velocity to cancel each other
	# 
	return (1.0 - _given_fraction) * vector
