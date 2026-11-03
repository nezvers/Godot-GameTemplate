## Free one-time chest: opens on interact and drops one weighted entry of `payouts`
## (contraptions.loot_box). Stays open for the run, so leaving the room and coming
## back doesn't refill it.
class_name LootBox
extends SlotMachine

@export var room_state_resource:RoomStateResource

func _ready()->void:
	super._ready()
	if room_state_resource != null && room_state_resource.is_looted(loot_key()):
		sprite.frame = 1

## "<room scene>:<node name>", unique per box for the run.
func loot_key()->String:
	var _room:Node = owner if owner != null else get_parent()
	return "%s:%s" % [_room.scene_file_path, name]

func is_opened()->bool:
	return sprite.frame == 1

func _can_use()->bool:
	return !is_opened()

func _use()->void:
	sprite.frame = 1
	if room_state_resource != null:
		room_state_resource.mark_looted(loot_key())
	_pay_out()

func _prompt_text()->String:
	return "Open" if !is_opened() else "Empty"
