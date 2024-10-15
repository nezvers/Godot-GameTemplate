## Data entry for ResourceNode, because Inspector is not fun.
class_name ResourceNodeItem
extends Resource

## Reference to a SaveableResource
@export var resource:SaveableResource
## Marks resource to be duplicated when a new ResourceNode is created
@export var make_unique:bool
@export_multiline var description:String

## Reference to actually used resource that probably is a duplicate
var value:SaveableResource
