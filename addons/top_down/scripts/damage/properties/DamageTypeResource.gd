class_name DamageTypeResource
extends Resource

@export var value:float

enum DamageType {
	PHYSICAL, 
	FIRE, 
	ICE, 
	LIGHTNING, 
	POISON, 
	ACID, 
	MAGNETIC, 
	BLOOD, 
	DARK, 
	ARCANE
	}

@export var type:DamageType
