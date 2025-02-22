class_name CollectingPoint
extends Node

@export var moved_node:Node2D

@export_flags_2d_physics var collision_mask:int

@export var area:Area2D

## TODO: upgradable detection range
@export var collision_shape:CollisionShape2D

@export var point_resource:ScoreResource

@export var pool_node:PoolNode

@export var player_reference:ReferenceNodeResource

@export var sound_collect:SoundResource

@export var axis_multiplication:Vector2Resource

@export var spawn_radius:float = 8.0

const SPAWN_TIME:float = 0.3

var tween:Tween

func _ready() -> void:
	request_ready()
	
	area.collision_mask = 0
	
	if tween != null:
		tween.kill()
	tween = create_tween()
	var _to:Vector2 = Vector2(spawn_radius, 0.0).rotated(randf_range(0.0, TAU)) * axis_multiplication.value + moved_node.global_position
	tween.tween_method(_tween_position.bind(moved_node.global_position, _to), 0.0, 1.0, SPAWN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(_init_area)
	
	player_reference.listen(self, _on_reference_update)

func _init_area()->void:
	area.collision_mask = collision_mask
	area.body_entered.connect(_on_body_enter, CONNECT_ONE_SHOT)

func _on_reference_update()->void:
	if player_reference.node != null:
		return
	
	if tween != null:
		tween.kill()

func _on_body_enter(_body:Node2D)->void:
	area.collision_mask = 0
	if tween != null:
		tween.kill()
	tween = create_tween()
	var _dir_away:Vector2 = (moved_node.global_position - player_reference.node.global_position).normalized()
	var _offset:Vector2 = _dir_away * spawn_radius * axis_multiplication.value + moved_node.global_position
	tween.tween_method(_tween_position.bind(moved_node.global_position, _offset), 0.0, 1.0, SPAWN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_tween_target_position.bind(_offset), 0.0, 1.0, SPAWN_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(_on_finished)

func _tween_position(t:float, from:Vector2, to:Vector2)->void:
	moved_node.global_position = from.lerp(to, t)
	
func _tween_target_position(t:float, from:Vector2)->void:
	moved_node.global_position = from.lerp(player_reference.node.global_position, t)

func _on_finished()->void:
	sound_collect.play_managed()
	point_resource.add_point()
	pool_node.pool_return()
