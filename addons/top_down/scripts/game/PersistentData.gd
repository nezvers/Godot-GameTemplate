extends Node

@export var instance_resource_list:Array[InstanceResource]
@export var saveable_list:Array[SaveableResource]
@export var shader_list:Array[Shader]

## Hold any data. Main use is to keep resources in memory
@export var data:Dictionary
