## Landing of a puddle gun shot (water, later acid and blood).
## Over the home base memory grid it soaks the one pillar it hit,
## anywhere else it leaves its puddle.
class_name PuddleOnLand
extends SpawnOnLand

const PISTON_GRID_REFERENCE:ReferenceNodeResource = preload("res://addons/top_down/resources/ReferenceNodeResources/piston_grid_reference.tres")

## Soaks a pillar instead of spawning the puddle (water)
@export var wets_pistons:bool = true

## Read through a variable: property reads on a const resource are folded at compile time
var grid_reference:ReferenceNodeResource = PISTON_GRID_REFERENCE

func _on_prepare_exit()->void:
	if wets_pistons:
		var _node:Node = grid_reference.node
		var _grid:PistonGrid = _node as PistonGrid
		if _grid != null && _grid.wet_at(projectile.global_position):
			return
	super._on_prepare_exit()
