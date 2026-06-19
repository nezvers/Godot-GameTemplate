## Scales this enemy's own HealthResource by the current difficulty multiplier.
## Native replacement for the old per-frame EnemyHealthScaler polling: runs in
## _ready() like ResetHealth, and is re-run on pool reuse via PoolNode.ready_nodes.
##
## Idempotent: caches the authoring baseline (reset_*) the first time it sees the
## resource, then always recomputes from that cache. No double-scaling on pool
## reuse, and slime splits each get a fresh node + freshly-duplicated resource.
class_name DifficultyHealth
extends Node

@export var resource_node: ResourceNode
@export var difficulty_resource: DifficultyResource

var _base_max: float = -1.0
var _base_hp: float = -1.0

func _ready() -> void:
	assert(resource_node != null)
	assert(difficulty_resource != null)
	var health: HealthResource = resource_node.get_resource("health") as HealthResource
	if health == null:
		return
	# Capture pristine authoring baseline once (first _ready, before any scaling).
	if _base_max < 0.0:
		_base_max = health.reset_max_hp
		_base_hp = health.reset_hp
	var mult: float = difficulty_resource.health_multiplier()
	health.reset_max_hp = _base_max * mult
	health.reset_hp = _base_hp * mult
	health.max_hp = health.reset_max_hp
	health.hp = health.reset_hp
	health.is_dead = false
	health.hp_changed.emit()
