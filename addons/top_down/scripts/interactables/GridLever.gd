## Lane select lever of the home base memory grid; PistonGrid places one per
## row (right edge) and one per column (bottom edge).
class_name GridLever
extends Interactable

@export var sprite:Sprite2D
## Lane number, counted from 1 at the corner by the control room
@export var number_label:Label

var grid:PistonGrid
var axis:PistonGrid.Axis
var index:int
var on:bool

func _ready()->void:
	super._ready()
	number_label.text = str(index + 1)

func set_on(value:bool)->void:
	on = value
	sprite.frame = int(on)

func _use()->void:
	grid.toggle(axis, index)

func _can_use()->bool:
	return grid != null && !grid.writing

func _prompt_text()->String:
	return "%s %d: %s" % ["Row" if axis == PistonGrid.Axis.ROW else "Column", index + 1, "ON" if on else "OFF"]
