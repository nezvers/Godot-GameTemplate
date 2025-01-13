class_name DamageSetup
extends Node

@export var resource_node:ResourceNode

@export var resistance_list:Array[DamageTypeResource]

func _ready() -> void:
	# BUG: workaround - https://github.com/godotengine/godot/issues/96181
	resistance_list = resistance_list.duplicate()
	
	_setup_resistance()
	# in case used with PoolNode
	resource_node.ready.connect(_setup_resistance)

func _setup_resistance()->void:
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	assert(_damage_resource != null)
	_damage_resource.owner = owner
	
	
