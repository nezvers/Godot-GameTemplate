## Picks the value the WriteButton puts into the selected cells: raise or lower.
class_name DataLever
extends GridControl

func _refresh()->void:
	var _grid:PistonGrid = get_grid()
	var _raise:bool = _grid == null || _grid.data_value
	sprite.frame = int(_raise)
	value_label.text = "RAISE" if _raise else "LOWER"

func _use()->void:
	get_grid().set_data_value(!get_grid().data_value)

func _prompt_text()->String:
	return "Data: %s" % ("RAISE" if get_grid() == null || get_grid().data_value else "LOWER")
