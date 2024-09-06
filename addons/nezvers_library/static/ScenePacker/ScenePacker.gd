class_name ScenePacker

static func create_package(_node:Node, makeLocal:bool = false)->PackedScene:
	set_owner(_node, _node, makeLocal)
	var package: = PackedScene.new()
# warning-ignore:return_value_discarded
	package.pack(_node)
	return package

static func set_owner(_node:Node, _owner:Node, makeLocal:bool = false)->void:
	for child in _node.get_children():
		if makeLocal: #everything is owned
			child.owner = _owner
		else:
			if child.owner == null: #only null is owned
				child.owner = _owner
		set_owner(child, _owner, makeLocal)
