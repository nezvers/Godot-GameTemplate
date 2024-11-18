extends Button

@export var action_resource:ActionResource

func _pressed()->void:
	action_resource.reset_resource()
