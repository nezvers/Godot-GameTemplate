## Instances a scene where the projectile lands (web trap, acid puddle, hatched spider).
class_name SpawnOnLand
extends Node

@export var projectile:Projectile2D

@export var instance_resource:InstanceResource

## When above 0, overrides spawned instance's "lifetime" (short lived boss puddles)
@export var lifetime:float = 0.0

func _ready()->void:
	projectile.prepare_exit_event.connect(_on_prepare_exit)

func _on_prepare_exit()->void:
	var _pos:Vector2 = projectile.global_position
	# set by EnemyLob when the shooter owns spawned enemies
	var _branch:ActiveEnemyResource = projectile.get_meta(&"enemy_branch") if projectile.has_meta(&"enemy_branch") else null
	if _branch != null && _branch.nodes.is_empty():
		# shooter died while projectile was in the air, don't spawn into a cleared wave
		return

	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = _pos
		if lifetime > 0.0 && &"lifetime" in inst:
			# after the trap's BalanceBinding writes its own lifetime on tree_entered
			inst.tree_entered.connect(inst.set.bind(&"lifetime", lifetime), CONNECT_ONE_SHOT)
		if _branch != null:
			ActiveEnemy.insert_child(inst, _branch)

	instance_resource.instance(_config_callback)
