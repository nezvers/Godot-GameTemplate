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
	ARCANE,
	## Last one for fetching total count
	COUNT,
	}

@export var type:DamageType
