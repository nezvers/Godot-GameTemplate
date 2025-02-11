class_name JumpMove
extends Node

signal jump_started
signal jump_finished

## During movement goes from 0.0 to 1.0
signal movement_interpolation(t:float)

@export var character_body:CharacterBody2D

## Sprite manipulated by jumping behaviour
@export var sprite:Sprite2D

## Sprite offset.y curve during jumping
@export var offset_curve:Curve

@export var stretch_node:Node2D
@export var jump_stretch:Vector2 = Vector2(0.8, 1.1)
@export var land_stretch:Vector2 = Vector2(1.2, 0.8)

## TODO: use sounds
@export var jump_sound:SoundResource
@export var land_sound:SoundResource

var move_tween:Tween
var stretch_tween:Tween
var is_jumping:bool
var receiver_collision_layer:int


## Used to multiply current frame distance as velocity per second
var physics_ticks:int

## Projected during tweening for velocity calculation
var previous_position:Vector2

func _ready() -> void:
	physics_ticks = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")

func move_target_position(value:Vector2, time:float)->void:
	if is_jumping:
		return
	is_jumping = true
	
	previous_position = character_body.global_position
	jump_started.emit()
	
	if move_tween != null:
		move_tween.kill()
	
	move_tween = create_tween()
	move_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	move_tween.tween_method(_move_body.bind(character_body.global_position, value), 0.0, 1.0, time)
	move_tween.finished.connect(_jump_finished.bind(value))
	
	if stretch_tween != null:
		stretch_tween.kill()
	stretch_tween = create_tween()
	stretch_tween.tween_method(_stretch_interpolation.bind(jump_stretch), 0.0, 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	jump_sound.play_managed()

func _move_body(t:float, from:Vector2, to:Vector2)->void:
	var _new_pos:Vector2 = from.lerp(to, t)
	var _distance:Vector2 = _new_pos - previous_position
	previous_position = _new_pos
	character_body.velocity = _distance * physics_ticks
	character_body.move_and_slide()
	
	sprite.offset.y = offset_curve.sample(t)
	
	movement_interpolation.emit(t)


func _jump_finished(target_pos:Vector2)->void:
	is_jumping = false
	character_body.velocity = Vector2.ZERO
	jump_finished.emit()
	
	if stretch_tween != null:
		stretch_tween.kill()
	stretch_tween = create_tween()
	stretch_tween.tween_method(_stretch_interpolation.bind(land_stretch), 0.0, 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	land_sound.play_managed()

func _stretch_interpolation(t:float, from:Vector2)->void:
	stretch_node.scale = from.lerp(Vector2.ONE, t)
