## Applies the owned meta-upgrades to a freshly spawned player.
## Balance has written the base values on the root's tree_entered, so the bonuses
## go on top of them once per player instance (no request_ready, so walking
## between rooms doesn't stack them). Health is reset again with the bonus, so
## the order against ResetHealth doesn't matter.
extends Node

@export var resource_node:ResourceNode
@export var meta_upgrade_resource:MetaUpgradeResource
@export var dash_ability:DashAbility
@export var damage_cooldown:Node
@export var weapon_manager:WeaponManager

func _ready()->void:
	assert(meta_upgrade_resource != null)
	var _meta:MetaUpgradeResource = meta_upgrade_resource

	var _health:HealthResource = resource_node.get_resource("health")
	var _hp:float = _meta.stat("max_hp")
	_health.reset_max_hp += _hp
	_health.reset_hp += _hp
	_health.reset_resource()

	var _movement:ActorStatsResource = resource_node.get_resource("movement")
	_movement.set_speed_multiplier(&"meta", 1.0 + _meta.stat("speed_ratio"))

	dash_ability.cooldown_time *= maxf(1.0 - _meta.stat("dash_cooldown_ratio"), 0.1)
	damage_cooldown.cooldown_time += _meta.stat("hit_invulnerability")
	weapon_manager.set_meta_damage_multiply(1.0 + _meta.stat("damage_ratio"))
