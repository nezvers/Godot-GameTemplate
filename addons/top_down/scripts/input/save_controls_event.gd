extends Node

@export var rebinding_panel:Control
@export var action_resource:ActionResource

func _ready()->void:
	assert(action_resource != null)
	assert(rebinding_panel != null)
	rebinding_panel.visibility_changed.connect(on_visibility_changed)

func on_visibility_changed()->void:
	if rebinding_panel.visible:
		return
	assert(!action_resource.resource_path.is_empty())
	action_resource.save_resource()
