class_name ItemTransmission
extends TransmissionResource

@export var item_resource:ItemResource

## Should result with a state change
func process(resource_node:ResourceNode)->void:
	match item_resource.type:
		ItemResource.ItemType.WEAPON:
			_weapon(resource_node)

func _weapon(resource_node:ResourceNode)->void:
	var _weapon_inventory:ItemCollectionResource = resource_node.get_resource("weapons")
	if _weapon_inventory.list.size() >= _weapon_inventory.max_items:
		failed()
		return
	
	_weapon_inventory.append(item_resource)
	success()
