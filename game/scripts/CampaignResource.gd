## Meta progress across games: New Game+ unlocks once a boss is killed and the
## player walks out through that boss room's victory exit. Also remembers which
## campaign the current run belongs to, so Try Again / Play Again restart it.
class_name CampaignResource
extends SaveableResource

signal updated

const NEW_GAME:String = "res://game/scenes/room_N00.tscn"
const NEW_GAME_PLUS:String = "res://game/scenes/room_P00.tscn"

## Saved: the title shows New Game+.
@export var ng_plus_unlocked:bool = false

## Start room of the current run (not saved; set by FreshStart).
var start_scene:String = NEW_GAME

func unlock_ng_plus()->void:
	if ng_plus_unlocked:
		return
	ng_plus_unlocked = true
	save_resource()
	updated.emit()

func restart_scene()->String:
	return start_scene if !start_scene.is_empty() else NEW_GAME

func reset_resource()->void:
	ng_plus_unlocked = false
	updated.emit()

func prepare_save()->Resource:
	var _data:CampaignResource = CampaignResource.new()
	_data.ng_plus_unlocked = ng_plus_unlocked
	return _data

func prepare_load(data:Resource)->void:
	ng_plus_unlocked = data.ng_plus_unlocked
	updated.emit()
