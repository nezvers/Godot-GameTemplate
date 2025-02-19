class_name DebugDraw
extends Node2D

static var singleton:DebugDraw

func _enter_tree() -> void:
	singleton = self
	global_position = Vector2.ZERO

func _exit_tree() -> void:
	if singleton == self:
		singleton = null

func _draw()->void:
	for _callback:Callable in list:
		_callback.call()

func erase(callback:Callable)->void:
	list.erase(callback)
	queue_redraw()

var list:Array[Callable]

static func debug_line2d(from:Vector2, to:Vector2, color:Color = Color.RED, time:float = 1.0)->void:
	if singleton == null:
		return
	var _callback:Callable = singleton.draw_line.bind(from, to, color)
	singleton.list.append(_callback)
	var _tween:Tween = singleton.create_tween()
	_tween.tween_callback(singleton.erase.bind(_callback)).set_delay(time)
	singleton.queue_redraw()

static func debug_distance2d(from:Vector2, distance:Vector2, color:Color = Color.RED, time:float = 1.0)->void:
	if singleton == null:
		return
	var _callback:Callable = singleton.draw_line.bind(from, from + distance, color)
	singleton.list.append(_callback)
	var _tween:Tween = singleton.create_tween()
	_tween.tween_callback(singleton.erase.bind(_callback)).set_delay(time)
	singleton.queue_redraw()

static func debug_rectangle(rect:Rect2, filled:bool = true, color:Color = Color.RED, time:float = 1.0)->void:
	if singleton == null:
		return
	var _callback:Callable = singleton.draw_rect.bind(rect, color, filled)
	singleton.list.append(_callback)
	var _tween:Tween = singleton.create_tween()
	_tween.tween_callback(singleton.erase.bind(_callback)).set_delay(time)
	singleton.queue_redraw()
