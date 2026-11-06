## One cell of the home base memory grid: a BlockWall raised and lowered by
## PistonGrid.write() instead of an arena section.
## A wet piston (water gun) shorts out when written and keeps its state.
class_name Piston
extends BlockWall

enum WriteResult {OK, UNCHANGED, SHORTED, BLOCKED}

## Top face rise of a fully raised piston (piston_strip4 frame 3)
const RAISED_HEIGHT:float = 14.0
## Draw offset that puts the frame's ground diamond on the origin (the footprint centre)
const SPRITE_OFFSET_Y:float = -7.0
## Sprite y-sort point while flat (frame 0): a tile up, so a lowered plate draws
## like floor, under anything standing on or next to it. Rising or raised it
## sorts at the footprint centre. The piston is y-sorted, so the sprite's own
## position is what sorts against actors.
const FLAT_SORT_Y:float = -16.0

## Seconds a soaked piston stays wet
@export var wet_time:float = 60.0

@export var sprite:Sprite2D
@export var wet_overlay:Sprite2D
@export var select_overlay:Sprite2D
@export var spark_sprite:Sprite2D
@export var spark_particles:CPUParticles2D
@export var body_shape:CollisionPolygon2D
@export var sound_short:SoundResource

## Physics layers checked before raising (player, enemies)
@export_flags_2d_physics var blocking_mask:int = 6

## Grid coordinates, set by PistonGrid
var cell:Vector2i

var _wet_left:float
var _spark_tween:Tween

func _ready()->void:
	sprite.frame_changed.connect(_sync_overlays)
	_sync_overlays()
	wet_overlay.visible = false
	select_overlay.visible = false
	spark_sprite.visible = false
	set_process(false)

func is_raised()->bool:
	return arena_door_block.is_raised()

func set_raised(raised:bool, instant:bool = false)->void:
	arena_door_block.set_raised(raised, instant)

## Lane-select preview: this cell will be written
func set_selected(value:bool)->void:
	select_overlay.visible = value

func is_wet()->bool:
	return _wet_left > 0.0

func wet()->void:
	_wet_left = wet_time
	wet_overlay.visible = true
	set_process(true)

func dry()->void:
	_wet_left = 0.0
	wet_overlay.visible = false
	set_process(false)

func _process(delta:float)->void:
	_wet_left -= delta
	if _wet_left <= 0.0:
		dry()

## Puts `value` into the cell. A wet cell shorts (sparks, keeps state); a cell
## with somebody standing on it can't rise.
func try_write(value:bool)->WriteResult:
	if is_wet():
		short_circuit()
		return WriteResult.SHORTED
	if value == is_raised():
		return WriteResult.UNCHANGED
	if value && is_occupied():
		deny_flash()
		return WriteResult.BLOCKED
	set_raised(value)
	return WriteResult.OK

func is_occupied()->bool:
	var _query:PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var _shape:ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	_shape.points = body_shape.polygon
	_query.shape = _shape
	_query.transform = body_shape.global_transform
	_query.collision_mask = blocking_mask
	return !get_world_2d().direct_space_state.intersect_shape(_query, 1).is_empty()

func short_circuit()->void:
	if sound_short != null:
		sound_short.play_managed()
	# origin is the ground footprint centre; the arcs are drawn 5px above the frame centre
	var _top:float = -RAISED_HEIGHT if is_raised() else 0.0
	spark_sprite.position.y = _top + 5.0
	spark_particles.position.y = _top
	spark_particles.restart()
	spark_particles.emitting = true
	if _spark_tween != null:
		_spark_tween.kill()
	spark_sprite.visible = true
	spark_sprite.frame = 0
	_spark_tween = create_tween()
	_spark_tween.tween_property(spark_sprite, "frame", spark_sprite.hframes - 1, 0.45).from(0)
	_spark_tween.parallel().tween_property(sprite, "modulate", Color(1.6, 1.6, 2.0), 0.05)
	_spark_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	_spark_tween.tween_callback(spark_sprite.hide)

func deny_flash()->void:
	var _tween:Tween = create_tween()
	_tween.tween_property(sprite, "modulate", Color(1.6, 0.5, 0.5), 0.08)
	_tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _sync_overlays()->void:
	wet_overlay.frame = sprite.frame
	select_overlay.frame = sprite.frame
	var _sort_y:float = FLAT_SORT_Y if sprite.frame == 0 else 0.0
	sprite.position.y = _sort_y
	for _layer:Sprite2D in [sprite, wet_overlay, select_overlay]:
		_layer.offset.y = SPRITE_OFFSET_Y - _sort_y
