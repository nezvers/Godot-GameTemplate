## Container for a room's arena combat nodes: the ArenaSection children
## (one per fight), the Aggregator that bridges to the global HUD resources,
## and the DropManager.
##
## Re-exposes each section's wave list at the root so a room integrating this
## scene can author all three fights directly on the EnemyManager node, without
## drilling into the Section1/2/3 children. Leave a list empty for a section
## that should count as already cleared on entry.
class_name EnemyManager
extends Node

## Waves for Section1 (authored per room). Pushed onto the Section1 child.
@export var section1_waves:Array[SpawnWaveList]
## Waves for Section2. Pushed onto the Section2 child.
@export var section2_waves:Array[SpawnWaveList]
## Waves for Section3. Pushed onto the Section3 child.
@export var section3_waves:Array[SpawnWaveList]

## The section nodes the wave lists are pushed onto (defaults wired in the scene).
@export var section1:ArenaSection
@export var section2:ArenaSection
@export var section3:ArenaSection

func _ready()->void:
	# Push root-authored waves onto each section. Only when non-empty, so a room
	# may still author waves directly on a Section child instead (the root export
	# left empty does not clobber it). Waves are read only once a fight starts,
	# well after every _ready, so child/parent ready order is irrelevant.
	if section1 != null && !section1_waves.is_empty():
		section1.waves = section1_waves
	if section2 != null && !section2_waves.is_empty():
		section2.waves = section2_waves
	if section3 != null && !section3_waves.is_empty():
		section3.waves = section3_waves
