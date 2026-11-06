## Base for the home base control room contraptions driving the PistonGrid
## (data lever, gate lever, write and reset buttons). Finds the grid through
## piston_grid_reference and refreshes its look whenever the grid changes.
class_name GridControl
extends Interactable

const PISTON_GRID_REFERENCE:ReferenceNodeResource = preload("res://addons/top_down/resources/ReferenceNodeResources/piston_grid_reference.tres")

@export var sprite:Sprite2D
## Optional text above the contraption (RAISE, AND, ...)
@export var value_label:Label

## Read through a variable: property reads on a const resource are folded at compile time
var grid_reference:ReferenceNodeResource = PISTON_GRID_REFERENCE

func _ready()->void:
	super._ready()
	grid_reference.listen(self, _on_grid_changed)

func get_grid()->PistonGrid:
	var _node:Node = grid_reference.node
	return _node as PistonGrid

func _on_grid_changed()->void:
	var _grid:PistonGrid = get_grid()
	if _grid != null && !_grid.changed.is_connected(_refresh):
		_grid.changed.connect(_refresh)
	_refresh()

## Override: show the grid's state
func _refresh()->void:
	pass

func _can_use()->bool:
	return get_grid() != null && !get_grid().writing
