## Multi-position lever picking how row and column selects combine into the
## cells a write touches: AND (crossings only), OR, XOR, NAND, NOR, XNOR.
class_name GateLever
extends GridControl

func _refresh()->void:
	var _grid:PistonGrid = get_grid()
	var _gate:PistonGrid.Gate = _grid.gate if _grid != null else PistonGrid.Gate.AND
	sprite.frame = _gate
	value_label.text = PistonGrid.gate_name(_gate)

func _use()->void:
	get_grid().next_gate()

func _prompt_text()->String:
	var _grid:PistonGrid = get_grid()
	if _grid == null:
		return "Gate"
	var _next:PistonGrid.Gate = ((_grid.gate + 1) % PistonGrid.Gate.size()) as PistonGrid.Gate
	return "Gate %s -> %s" % [PistonGrid.gate_name(_grid.gate), PistonGrid.gate_name(_next)]
