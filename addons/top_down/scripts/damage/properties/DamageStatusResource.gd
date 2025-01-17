## Base class.
## Can be used as buff or bleed effect, or spawn scenes at specific events relative to actor.
class_name DamageStatusResource
extends Resource


## Function to decide if status applies and how it executes it.
## TODO: need reference to DamageDataResource giver and receiver to report damage done by status effect.
func process(resource_node:ResourceNode, damage_resource:DamageResource = null, is_stored:bool = false)->void:
	if damage_resource == null:
		damage_resource = resource_node.get_resource("damage")
	
	# if need to be stored and carried between scenes but this instance isn't stored yet
	if !is_stored:
		## TODO: Test if stacking should be allowed
		damage_resource.add_status_effect(self.duplicate())
