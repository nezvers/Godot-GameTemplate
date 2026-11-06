## Commits the data value to every cell the lane selects and the gate pick.
class_name WriteButton
extends GridControl

func _can_use()->bool:
	return super._can_use() && get_grid().selected_count() > 0

func _use()->void:
	sprite.frame = 1
	var _grid:PistonGrid = get_grid()
	_grid.written.connect(func(_results:Dictionary)->void: sprite.frame = 0, CONNECT_ONE_SHOT)
	_grid.write()

func _prompt_text()->String:
	var _grid:PistonGrid = get_grid()
	if _grid == null:
		return "Write"
	var _count:int = _grid.selected_count()
	if _count == 0:
		return "Write (nothing selected)"
	return "Write %s x%d" % ["RAISE" if _grid.data_value else "LOWER", _count]
