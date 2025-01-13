## Transmission for 
class_name HoleTransmission
extends TransmissionResource

func process(resource_node:ResourceNode)->void:
	var _dash_resource:Resource = resource_node.get_resource("dash")
	if _dash_resource != null:
		if _dash_resource.value == true:
			try_again()
			return
	
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	if _damage_resource == null:
		failed()
		return
	# damage receiving is disabled
	# TODO: toggling bool state is asking for a bug - NEED A SOLUTION!!!
	if !_damage_resource.can_receive_damage:
		try_again()
		return
	
	var _hole_bool:BoolResource = resource_node.get_resource("hole")
	if _hole_bool == null:
		failed()
		return
	_hole_bool.set_value(true)
