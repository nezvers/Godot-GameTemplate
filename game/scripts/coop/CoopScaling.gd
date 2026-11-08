## Co-op numbers from balance.json "coop": tougher, longer fights per extra
## player and the revive rules. Everything is 1x / off in single player.
class_name CoopScaling
extends RefCounted

## Players in the session (1 offline).
static func players()->int:
	return maxi(RunSession.players.count_active(), 1) if Net.is_online() else 1

## Enemy max hp multiplier (DifficultyHealth).
static func health_ratio()->float:
	return 1.0 + float(Balance.value("coop.enemy_health_per_player", 0.5)) * (players() - 1)

## Kills per wave multiplier (ArenaSection).
static func wave_ratio()->float:
	return 1.0 + float(Balance.value("coop.wave_count_per_player", 0.35)) * (players() - 1)

static func revive_time()->float:
	return float(Balance.value("coop.revive_time", 3.0))

static func revive_radius()->float:
	return float(Balance.value("coop.revive_radius", 20.0))

static func revive_hp_ratio()->float:
	return float(Balance.value("coop.revive_hp_ratio", 0.3))

## Loot drops: false = shared (first to touch it takes it), true = every player
## gets their own copy of every drop. Read on the host. A meta upgrade can turn
## it on later.
static func loot_per_player()->bool:
	return bool(Balance.value("coop.loot_per_player", false))
