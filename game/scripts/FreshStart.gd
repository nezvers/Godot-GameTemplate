## Ensures a clean game start when entering the starting room.
## room_start is only reached from the title or victory screen (never via a
## door-back), so any carried player/transition state is stale and must be reset
## BEFORE PlayerSpawner._ready runs — otherwise PlayerSpawner sees a lingering
## player_reference and tries the door-entry path (which needs an entry_match
## that doesn't exist here), leaving the player unplaced or outside the room.
##
## Runs in _enter_tree so it executes before any sibling/parent _ready.
extends Node

## Carried player reference (cleared on the player node's tree_exiting).
@export var player_reference: ReferenceNodeResource

## Transition state carried between rooms.
@export var scene_transition_resource: SceneTransitionResource

func _enter_tree() -> void:
	assert(player_reference != null)
	assert(scene_transition_resource != null)

	# Free any stale, detached player from a previous run so PlayerSpawner spawns
	# a fresh one at its marker.
	var stale: Node = player_reference.node
	if stale != null:
		player_reference.remove_reference(stale)
		if is_instance_valid(stale) and stale.get_parent() == null:
			stale.queue_free()

	# Clear transition info so PlayerSpawner takes the fresh-spawn branch.
	scene_transition_resource.next_scene_path = ""
	scene_transition_resource.entry_tag = ""
	scene_transition_resource.entry_match = null
