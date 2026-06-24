@tool
## Root of the BlockWall scene. Re-exposes the two values a room usually wants
## to tweak per-instance (which arena section drives it, and whether it is a
## fight BARRIER or a clear-once GATE) so they can be set directly on the
## instanced node without diving into the inner ArenaDoorBlock child.
class_name BlockWall
extends Node2D

## Which arena section's state drives this wall.
@export var section:ArenaSection : set = set_section

## BARRIER raises while the section fights; GATE is up by default and lowers
## permanently once the section clears.
@export var mode:ArenaDoorBlock.WallMode = ArenaDoorBlock.WallMode.BARRIER : set = set_mode

@export var arena_door_block:ArenaDoorBlock

func set_section(value:ArenaSection)->void:
	section = value
	if arena_door_block != null:
		arena_door_block.section = value

func set_mode(value:ArenaDoorBlock.WallMode)->void:
	mode = value
	if arena_door_block != null:
		arena_door_block.mode = value
