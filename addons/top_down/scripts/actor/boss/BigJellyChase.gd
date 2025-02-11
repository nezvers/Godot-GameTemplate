class_name BigJellyChase
extends Node

signal finished

@export var jump_move:JumpMove

@export var target_offset:Vector2

@export var jump_time:float = 1.0

## TODO: could be used for difficulity
@export var landing_recovery_time:float = 0.32

@export var axis_multiplication:Vector2Resource

@export var landing_vfx:InstanceResource

@export var enabled:bool = true

## Multiplied by axis_multiplication
var direction:Vector2

var distance_length:float
var jump_pos:Vector2
var axis_compensation:Vector2

func _ready() -> void:
	jump_move.jump_finished.connect(_on_landing)
	axis_compensation = Vector2.ONE / axis_multiplication.value

func jump_at_target()->void:
	if !enabled:
		return
	jump_move.move_target_position(jump_pos, jump_time)

func target_calculation(target_position:Vector2, target_velocity:Vector2, max_distance:float)->void:
	var _player_velocity_offset:Vector2 = target_velocity * jump_time
	var _target_pos = target_position + _player_velocity_offset + target_offset
	var _distance:Vector2 = (_target_pos - jump_move.character_body.global_position) * axis_compensation
	distance_length = min(_distance.length(), max_distance)
	direction = _distance.normalized() * axis_multiplication.value
	jump_pos = jump_move.character_body.global_position + direction * distance_length

func _on_landing()->void:
	var _tween:Tween = create_tween()
	_tween.tween_callback(_on_landing_timeout).set_delay(landing_recovery_time)
	
	var _vfx_config:Callable = func (inst:Node2D)->void:
		inst.global_position = jump_move.character_body.global_position - target_offset
	landing_vfx.instance(_vfx_config)

func _on_landing_timeout()->void:
	finished.emit()
