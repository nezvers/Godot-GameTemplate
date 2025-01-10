extends Node


@export var enabled:bool = true

## Node that will be rotated
@export var rotated_node:Node2D

## Node that does the movement logic
@export var projectile:Projectile2D

@export var mover:ProjectileMover

## visuals are continuously updated in _process
@export var is_continuous:bool = false

## Instead of fully rotate use vertical flipping to look like it's flipping horizontally
@export var flip_horizontaly:bool = true

## Toggle ability to continuously update rotation
func set_enabled(value:bool)->void:
	enabled = value
	set_process(is_continuous && enabled)

func _ready()->void:
	set_process(is_continuous && enabled)
	if !is_continuous && !mover.bounce_position.is_connected(_rotate_visuals):
		mover.bounce_position.connect(_rotate_visuals)
	_rotate_visuals()

## Calculate the rotation and sprite flipping
func _rotate_visuals()->void:
	if !enabled:
		return
	var direction:Vector2 = projectile.direction
	if flip_horizontaly && direction.x != 0.0:
		rotated_node.scale.y = sign(direction.x)
	rotated_node.rotation = direction.angle()

## used if is_continuous
func _process(_delta:float)->void:
	_rotate_visuals()
