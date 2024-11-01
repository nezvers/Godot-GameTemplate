## Resource to reference a Node and receive notification when the reference is changed.
class_name ReferenceNodeResource
extends Resource

## Notification signal when reference has been changed
signal updated

## Referenced node shared between resource holders
var node:Node

## Callback list for change listeners
var listeners:Array[Callable]


## Sets referenced to the Node.
## until_exit will automatically remove reference using tree_exited
func set_reference(value:Node, until_exit:bool = true)->void:
	node = value
	for callback in listeners:
		callback.call()
	if value != null && until_exit:
		value.tree_exiting.connect(remove_reference.bind(node), CONNECT_ONE_SHOT)
	updated.emit()


## If provided node is currently the reference then the reference will be set to null
func remove_reference(value:Node)->void:
	if node != value:
		return
	node = null
	for callback in listeners:
		callback.call()
	updated.emit()


## Bind callback on each reference change and call it as an initialization call
## until_exit will remove callback when listener exits a scene tree.
func listen(inst:Node, callback:Callable, until_exit:bool = true)->void:
	listeners.append(callback)
	if until_exit:
		inst.tree_exited.connect(erase_listener.bind(callback), CONNECT_ONE_SHOT)
	callback.call()


## Remove callback from listening reference change.
func erase_listener(callback:Callable)->void:
	listeners.erase(callback)
