class_name DamageSetup
extends Node

@export var resource_node:ResourceNode

@export var resistance_list:Array[DamageTypeResource]

var damage_resource:DamageResource

func _ready() -> void:
	# BUG: workaround - https://github.com/godotengine/godot/issues/96181
	resistance_list = resistance_list.duplicate()
	
	_setup_resistance()
	# in case used with PoolNode
	resource_node.ready.connect(_setup_resistance)

func _setup_resistance()->void:
	damage_resource = resource_node.get_resource("damage")
	assert(damage_resource != null)
	damage_resource.owner = owner
	
	damage_resource.resistance_value_list.resize(DamageTypeResource.DamageType.COUNT)
	damage_resource.resistance_value_list.fill(0.0)
	
	for _resistance:DamageTypeResource in resistance_list:
		# Add in case there are multiple of the same type
		damage_resource.resistance_value_list[_resistance.type] += _resistance.value

func add_resistance(resistance:DamageTypeResource)->void:
	resistance_list.append(resistance)
	damage_resource.resistance_value_list[resistance.type] += resistance.value

func remove_resistance(resistance:DamageTypeResource)->void:
	if !resistance_list.has(resistance):
		return
	
	resistance_list.erase(resistance)
	damage_resource.resistance_value_list[resistance.type] -= resistance.value
