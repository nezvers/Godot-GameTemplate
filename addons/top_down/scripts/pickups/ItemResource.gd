class_name ItemResource
extends Resource

@export var icon:Texture2D

@export var scene_path:String

enum ItemType {
	WEAPON,
}

@export var type:ItemType

@export var unlocked:bool
