## Saves a zoomed-out picture of a room with a grid of world coordinates, for placing props.
##   Godot --path . res://game/tests/room_snapshot.tscn -- <room.tscn> <out.png> [loot]
## "loot" adds a slime ball first so the slime workbench shows.
extends Node2D

func _ready()->void:
	var _args:PackedStringArray = OS.get_cmdline_user_args()
	# The boot screen normally registers the input actions
	(load("res://addons/top_down/resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	if _args.size() > 2 && _args[2] == "loot":
		(load("res://addons/top_down/resources/global_resources/slime_resource.tres") as ScoreResource).add(1)
	var _room:Node = (load(_args[0]) as PackedScene).instantiate()
	add_child(_room)
	for _i:int in 20:
		await get_tree().process_frame
	var _floor:TileMapLayer = _room.get_node("Background/FloorLayer")
	var _rect:Rect2i = _floor.get_used_rect()
	var _a:Vector2 = _floor.to_global(_floor.map_to_local(_rect.position))
	var _b:Vector2 = _floor.to_global(_floor.map_to_local(_rect.end))
	var _c:Vector2 = _floor.to_global(_floor.map_to_local(Vector2i(_rect.position.x, _rect.end.y)))
	var _d:Vector2 = _floor.to_global(_floor.map_to_local(Vector2i(_rect.end.x, _rect.position.y)))
	var _min:Vector2 = Vector2(minf(minf(_a.x, _b.x), minf(_c.x, _d.x)), minf(minf(_a.y, _b.y), minf(_c.y, _d.y)))
	var _max:Vector2 = Vector2(maxf(maxf(_a.x, _b.x), maxf(_c.x, _d.x)), maxf(maxf(_a.y, _b.y), maxf(_c.y, _d.y)))
	var _camera:Camera2D = Camera2D.new()
	add_child(_camera)
	_camera.global_position = (_min + _max) * 0.5
	var _size:Vector2 = get_viewport_rect().size
	var _zoom:float = minf(_size.x / (_max.x - _min.x + 64.0), _size.y / (_max.y - _min.y + 64.0))
	_camera.zoom = Vector2.ONE * _zoom
	_camera.make_current()
	var _grid:Node2D = Grid.new()
	_grid.from = (_min / 32.0).floor() * 32.0
	_grid.to = (_max / 32.0).ceil() * 32.0
	_grid.z_index = 100
	add_child(_grid)
	for _i:int in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_args[1])
	print("room bounds ", _min, " .. ", _max)
	get_tree().quit()

class Grid extends Node2D:
	var from:Vector2
	var to:Vector2
	func _draw()->void:
		var _font:Font = ThemeDB.fallback_font
		var x:float = from.x
		while x <= to.x:
			draw_line(Vector2(x, from.y), Vector2(x, to.y), Color(1, 1, 0, 0.25))
			draw_string(_font, Vector2(x + 1, from.y + 8), str(int(x)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.YELLOW)
			x += 32.0
		var y:float = from.y
		while y <= to.y:
			draw_line(Vector2(from.x, y), Vector2(to.x, y), Color(1, 1, 0, 0.25))
			draw_string(_font, Vector2(from.x + 1, y - 1), str(int(y)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.CYAN)
			y += 32.0
