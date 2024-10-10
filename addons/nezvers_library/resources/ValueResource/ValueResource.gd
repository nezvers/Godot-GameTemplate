class_name ValueResource
extends SaveableResource

## Child classes should emit when changing value 
signal updated

## Solely created to remove unused warning
func _stupid_warnings()->void:
	updated.emit()
