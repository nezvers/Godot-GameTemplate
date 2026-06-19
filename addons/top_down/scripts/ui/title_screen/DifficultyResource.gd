## Game difficulty setting. Saved to disk like other settings (graphics/audio).
## Easy lowers all enemy health to a quarter of Normal.
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

## Multiplier applied to enemy health. Normal = 1.0, Easy = 0.25 (4x lower).
func health_multiplier() -> float:
	return 0.25 if mode == Mode.EASY else 1.0

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
