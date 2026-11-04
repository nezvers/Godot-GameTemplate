## Game difficulty setting. Saved to disk like other settings (graphics/audio).
## Per-mode ratios (enemy health, damage, wave sizes) come from balance.json.
class_name DifficultyResource
extends SaveableResource

signal updated

enum Mode { NORMAL, EASY }

@export var mode: int = Mode.NORMAL

func set_mode(value: int) -> void:
	mode = value
	updated.emit()

func toggle() -> void:
	set_mode(Mode.NORMAL if mode == Mode.EASY else Mode.EASY)

## Ratio from balance.json "difficulty.<mode>.<key>", 1.0 when not set.
func ratio(key: String) -> float:
	return Balance.ratio(mode_name().to_lower(), key)

## Multiplier applied to enemy health.
func health_multiplier() -> float:
	return ratio("enemy_health_ratio")

## Multiplier applied to damage the player takes.
func damage_multiplier() -> float:
	return ratio("enemy_damage_ratio")

## Multiplier applied to how many enemies a normal wave has.
func wave_count_multiplier() -> float:
	return ratio("wave_count_ratio")

## Multiplier applied to a wave's max_alive cap; 0 or less means no cap.
func max_alive_multiplier() -> float:
	return ratio("max_alive_ratio")

## Seconds between a timed spawn point's extra spawns; 0 = no spawn timers.
func spawn_interval() -> float:
	return float(Balance.value("difficulty.%s.spawn_interval" % mode_name().to_lower(), 0.0))

## Spawn points per wave that run a spawn timer, before HORDE upgrades add more.
func timed_spawners() -> int:
	return int(Balance.value("difficulty.%s.timed_spawners" % mode_name().to_lower(), 0))

func is_easy() -> bool:
	return mode == Mode.EASY

func mode_name() -> String:
	return "Easy" if mode == Mode.EASY else "Normal"

## --- SaveableResource overrides (mirror GraphicsResource) ---

func prepare_save() -> Resource:
	return self.duplicate()

func prepare_load(data: Resource) -> void:
	mode = data.mode
	updated.emit()

func reset_resource() -> void:
	mode = Mode.NORMAL
	updated.emit()
