## Game-owned HUD overlay drawn on top of the template's game_hud.
## The "Room cleared" / "Cleared" banner now lives in the template GameHud's
## WaveLabel (see wave_label.gd), so this overlay's label is kept hidden.
extends CanvasLayer

## Legacy cleared banner, now superseded by the WaveLabel. Kept hidden.
@export var cleared_label: Label

## Shared flag (BoolResource): true when the current room is cleared.
@export var room_cleared_resource: BoolResource

func _ready() -> void:
	if cleared_label != null:
		cleared_label.visible = false
