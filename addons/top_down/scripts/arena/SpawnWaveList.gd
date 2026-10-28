class_name SpawnWaveList
extends Resource

@export var is_boss:bool

## Name shown on the boss wave banner (boss waves only).
@export var display_name:String

@export var count:int

## Most enemies of this wave alive at once, 0 = only limited by spawn points.
@export var max_alive:int

@export var instance_list:Array[InstanceResource]
