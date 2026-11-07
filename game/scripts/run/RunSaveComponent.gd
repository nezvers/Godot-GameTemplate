## A piece of shared run state stored in a RunSave checkpoint.
## Adding new run state: subclass this, give it a unique id(), and append the
## script to RunSession.COMPONENTS. Older saves without it get a fresh instance
## (capture never ran, so apply() must cope with defaults); saves holding an id
## the game no longer knows are skipped.
@abstract
class_name RunSaveComponent
extends Resource

## Bumped by the subclass when its stored fields change; migrate() upgrades older data.
@export var component_version:int

@abstract func id()->StringName

## Copies live state into this component's exported fields.
@abstract func capture()->void

## Writes the stored fields back into the live state.
@abstract func apply()->void

## Called on load when component_version is older than the current one.
func migrate(_from_version:int)->void:
	pass

## The version the code writes now; subclasses override when they bump it.
func current_version()->int:
	return 1
