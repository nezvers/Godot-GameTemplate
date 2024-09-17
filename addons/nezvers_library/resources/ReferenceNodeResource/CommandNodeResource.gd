## Add functionality to send commands to referenced node or a callback function.
class_name CommandNodeResource
extends ReferenceNodeResource

signal callback_changed

## Doesn't require for a node to be set
## It will be called by `callback` function.
var callable:Callable

## Sets inner callable value
func set_callable(value:Callable)->void:
	callable = value
	callback_changed.emit()

## IMPORTANT: caller need to match callable signature
func callback(value_list:Array)->void:
	assert(!callable.is_null())
	if value_list.is_empty():
		callable.call()
	else:
		callable.call(value_list)

## Requires for a node to be set
## IMPORTANT: caller need to know function signature
func command(method:StringName, value_list:Array)->void:
	assert(node != null)
	node.callv(method, value_list)
