extends Object

## Allows the registration of anonymous singletons into the scene tree.


const HOLDER_NAME: String = "PluginSingletons"


static func instance_of(p_script: Script, requester: Node) -> Variant:
	var holder: Node = requester.get_tree().get_root().get_node_or_null(HOLDER_NAME)

	if not is_instance_valid(holder):
		holder = Node.new()
		holder.name = HOLDER_NAME
		requester.get_tree().get_root().add_child(holder)

	for child in holder.get_children():
		if child.get_script() == p_script:
			return child

	var instance: Node = p_script.new()
	holder.add_child(instance)
	return instance
