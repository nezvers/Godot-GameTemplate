class_name DamageStatusResource
extends Resource

## chance to trigger status effect
@export_range(0.0, 1.0) var chance:float = 0.3

@export var value:DamageTypeResource

@export var tick_interval:float

@export var tick_count:int = 1
