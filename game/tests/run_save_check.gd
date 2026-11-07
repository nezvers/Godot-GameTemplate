## Mid-run checkpoint (RunSave / RunSession): a new run writes a checkpoint at the
## start room, progress and the player's state round-trip through the file,
## Continue spawns the player at the saved door with its hp, weapons, coins and
## upgrades, cleared rooms stay cleared, and game over/victory delete the save.
## Scene changes are done by hand (Transition needs a real screen).
##   Godot --headless --path . res://game/tests/run_save_check.tscn
extends Node

const TD:String = "res://addons/top_down/"
const ROOM_N00:String = "res://game/scenes/room_N00.tscn"
const ROOM_N01:String = "res://game/scenes/room_N01.tscn"

var failures:int = 0
var checks:int = 0

var _inventory:ItemCollectionResource
var _database:ItemCollectionResource
var _score:ScoreResource
var _slime:ScoreResource
var _upgrades:WeaponUpgradeResource
var _room_state:RoomStateResource
var _transition:SceneTransitionResource
var _player_reference:ReferenceNodeResource
var _health:HealthResource
var _home:HomeBaseResource
var _home_name:String
var _room:Node

func check(condition:bool, label:String)->void:
	checks += 1
	if !condition:
		failures += 1
		printerr("FAIL: ", label)

func _ready()->void:
	RunSave.file_name = "RunSave_test"
	RunSave.delete_file()
	(load(TD + "resources/global_resources/action_resource.tres") as ActionResource).reset_resource()
	_inventory = load(TD + "resources/ItemCollectionResource/weapon_inventory.tres")
	_database = load(TD + "resources/ItemCollectionResource/weapon_database.tres")
	_score = load(TD + "resources/global_resources/score_resource.tres")
	_slime = load(TD + "resources/global_resources/slime_resource.tres")
	_upgrades = load(TD + "resources/global_resources/weapon_upgrade_resource.tres")
	_room_state = load(TD + "resources/global_resources/room_state_resource.tres")
	_transition = load(TD + "resources/global_resources/scene_transition_resource.tres")
	_player_reference = load(TD + "resources/ReferenceNodeResources/player_reference.tres")
	_health = load(TD + "resources/health_resource/player_health.tres")
	# FreshStart hands over (and saves) the home base loadout
	_home = load("res://game/resources/home_base_resource.tres")
	_home_name = _home.resource_name
	_home.resource_name = _home_name + "_test"

	_check_scenes()
	_check_file_safety()

	# New run: the start room writes the first checkpoint once the player is placed
	await _load_room(ROOM_N00)
	check(_player_reference.node != null, "new run: player spawned")
	check(RunSession.active, "new run: run active")
	check(RunSave.exists(), "new run: checkpoint written at the start room")
	var _first:RunSave = RunSave.read()
	check(_first != null && _first.room_scene == ROOM_N00, "checkpoint names the start room")
	check(_first != null && _first.entry_tag == "", "start room checkpoint uses the spawn marker")

	# Progress: weapons, coins, slime, an upgrade, lost hp, a cleared room
	var _gun:ItemResource = _database.list[1]
	var _other:ItemResource = _database.list[2]
	_inventory.append(_gun)
	_inventory.append(_other)
	_inventory.set_selected(1)
	_score.add(12)
	_slime.add(3)
	_upgrades.levels[_gun.scene_path] = 2
	await _frames(3)
	_health.add_hp(-2.0)
	var _hp_left:float = _health.hp
	_room_state.mark_cleared(&"room_N00")
	_room_state.mark_section_cleared(&"room_N01", 1)
	_room_state.mark_looted("res://game/scenes/room_N01.tscn:LootBox1")
	await _frames(2)
	var _save:RunSave = RunSave.read()
	check(_save != null, "room progress rewrote the checkpoint")
	if _save == null:
		_finish()
		return
	var _player:PlayerRunData = _save.players[0] if !_save.players.is_empty() else null
	check(_player != null && _player.slot == 0, "local player saved in slot 0")
	check(_player != null && _player.profile_id == RunSession.profile.profile_id, "player saved with the profile id")
	check(_player != null && _player.weapons == PackedStringArray([_gun.resource_name, _other.resource_name]), "weapons saved by name")
	check(_player != null && _player.selected == 1, "selected weapon saved")
	check(_player != null && int(_player.wallet.get("coin", {}).get("value", -1)) == _score.value, "coins saved")
	check(_player != null && int(_player.wallet.get("slime", {}).get("value", -1)) == 3, "slime saved")
	check(_player != null && int(_player.weapon_levels.get(_gun.scene_path, 0)) == 2, "weapon upgrade saved")
	var _progress:RoomProgressComponent = _save.get_component(&"room_progress")
	check(_progress != null && _progress.cleared_rooms.has("room_N00"), "cleared room saved")
	check(_progress != null && Array(_progress.cleared_sections.get("room_N01", [])).has(1), "cleared section saved")
	check(_progress != null && _progress.looted.has("res://game/scenes/room_N01.tscn:LootBox1"), "opened loot box saved")
	check(_save.campaign_start_scene == ROOM_N00, "campaign start room saved")
	var _coins:int = _score.value

	# Quit to the title: everything run-scoped is forgotten in memory
	await _unload_room()
	RunSession.suspend()
	_inventory.reset_resource()
	_score.reset_resource()
	_slime.reset_resource()
	_upgrades.reset_resource()
	_room_state.reset_resource()
	check(RunSave.exists(), "suspending keeps the checkpoint")
	check(RunSession.has_save(), "title Continue is offered")

	# Continue into another room through a door
	_save.room_scene = ROOM_N01
	_save.entry_tag = "n01_n02"
	RunSession.apply_save(_save)
	check(RunSession.is_resuming(), "resume pending until the party is placed")
	await _load_room(ROOM_N01)
	var _node:Node2D = _player_reference.node
	check(_node != null, "resume: player spawned")
	check(!RunSession.is_resuming(), "resume consumed")
	var _door:Node2D = _room.get_node("Behind/Stairs2")
	check(_node != null && _node.global_position.distance_to(_door.global_position) < 24.0, "resume: player placed at the saved door")
	check(_inventory.list.size() == 2 && _inventory.list[0] == _gun && _inventory.list[1] == _other, "resume: weapons restored")
	check(_inventory.selected == 1, "resume: selected weapon restored")
	check(_score.value == _coins && _slime.value == 3, "resume: wallet restored")
	check(_upgrades.get_level(_gun.scene_path) == 2, "resume: weapon upgrade restored")
	check(is_equal_approx(_health.hp, _hp_left), "resume: hp restored after spawn reset (%s vs %s)" % [_health.hp, _hp_left])
	check(_room_state.is_cleared(&"room_N00") && _room_state.is_section_cleared(&"room_N01", 1), "resume: room progress restored")
	check(_room_state.is_looted("res://game/scenes/room_N01.tscn:LootBox1"), "resume: looted boxes restored")
	var _after:RunSave = RunSave.read()
	check(_after != null && _after.room_scene == ROOM_N01 && _after.entry_tag == "n01_n02", "resumed room re-checkpointed")

	# A resume into a start room must not be wiped by FreshStart
	await _unload_room()
	_save.room_scene = ROOM_N00
	_save.entry_tag = ""
	RunSession.apply_save(_save)
	await _load_room(ROOM_N00)
	check(_inventory.list.size() == 2, "resume into a start room keeps the run")

	# An older save without components still loads (fresh defaults)
	var _bare:RunSave = RunSession.capture()
	_bare.components.clear()
	RunSession.apply_save(_bare)
	check(!_room_state.is_cleared(&"room_N00"), "missing component applies its defaults")
	RunSession._resume_data = null

	_check_coop_save()

	# Game over ends the run
	RunSession.end_run()
	check(!RunSave.exists(), "end_run deletes the checkpoint")
	check(!RunSession.has_save(), "no Continue after the run ended")
	_finish()

## Co-op: a guest's own state goes into the host's checkpoint and waits there
## for the guest to come back.
func _check_coop_save()->void:
	var _data:PlayerRunData = PlayerRunData.new()
	_data.hp = 21.0
	_data.max_hp = 60.0
	_data.weapons = PackedStringArray(["Shotgun", "Gun"])
	_data.selected = 1
	_data.weapon_levels = {"res://x.tscn": 2}
	_data.wallet = {"coin": {"value": 7, "collected_total": 9}}
	var _back:PlayerRunData = PlayerRunData.from_dict(_data.to_dict())
	check(_back != null && _back.hp == 21.0 && _back.weapons == _data.weapons && _back.selected == 1, "guest run data: round trip over the wire")
	check(_back != null && _back.wallet.coin.value == 7 && _back.weapon_levels["res://x.tscn"] == 2, "guest run data: wallet and levels")
	check(PlayerRunData.from_dict({"hp": "lots"}) == null, "guest run data: wrong types refused")
	var _many:Dictionary = _data.to_dict()
	var _list:PackedStringArray = []
	for _i:int in 40:
		_list.append("Gun")
	_many.weapons = _list
	check(PlayerRunData.from_dict(_many) == null, "guest run data: oversized lists refused")

	var _guest:PlayerState = PlayerState.create_remote("guest_profile_123", "Friend", 1)
	_guest.guest_run_data = _back
	RunSession.players.add(_guest)
	var _save:RunSave = RunSession.capture()
	RunSession.players.remove(1)
	var _saved:PlayerRunData = null
	for _entry:PlayerRunData in _save.players:
		if _entry.profile_id == "guest_profile_123":
			_saved = _entry
	check(_saved != null && _saved.slot == 1 && _saved.weapons == _data.weapons && _saved.hp == 21.0, "co-op save: the guest's own state is stored")
	check(_save.mode == RunSave.Mode.SINGLE, "offline capture stays single player")

	# Continue without the guest: its data waits, and stays in later checkpoints
	RunSession.apply_save(_save)
	RunSession._resume_data = null
	check(RunSession.waiting_guests.has("guest_profile_123"), "continue: absent guest's data kept for its return")
	var _again:RunSave = RunSession.capture()
	check(_again.players.any(func (e:PlayerRunData)->bool: return e.profile_id == "guest_profile_123"), "continue: absent guest still in the next checkpoint")
	RunSession.waiting_guests.clear()

func _check_scenes()->void:
	var _title:String = FileAccess.get_file_as_string("res://game/scenes/title.tscn")
	check(_title.contains("ContinueButton.gd"), "title Continue has its script")
	var _pause:String = FileAccess.get_file_as_string(TD + "scenes/ui/screens/pause.tscn")
	check(_pause.contains("SaveAndExitButton.gd"), "pause Main Menu saves the run first")
	var _over:String = FileAccess.get_file_as_string(TD + "scripts/game/GameOverDetect.gd")
	check(_over.contains("RunSession.end_run()"), "game over ends the run")
	var _win:String = FileAccess.get_file_as_string("res://game/scripts/VictoryScreen.gd")
	check(_win.contains("RunSession.end_run()"), "victory ends the run")

func _check_file_safety()->void:
	var _file:FileAccess = FileAccess.open(RunSave.file_path(), FileAccess.WRITE)
	_file.store_string('[gd_resource type="Resource" format=3]\n[sub_resource type="GDScript" id="x"]\nscript/source = "extends Resource"\n[resource]\n')
	_file.close()
	check(RunSave.read() == null, "a save carrying a script is rejected")
	_file = FileAccess.open(RunSave.file_path(), FileAccess.WRITE)
	_file.store_string("garbage")
	_file.close()
	check(RunSave.read() == null, "an unreadable save is ignored")
	RunSave.delete_file()
	check(RunSave.read() == null, "no save file reads as none")

func _load_room(path:String)->void:
	await _unload_room()
	_room = (load(path) as PackedScene).instantiate()
	add_child(_room)
	await _frames(10)

func _unload_room()->void:
	if _room == null:
		return
	var _carried:Node = _player_reference.node
	_room.queue_free()
	_room = null
	await _frames(2)
	if _carried != null:
		_player_reference.remove_reference(_carried)
	_transition.next_scene_path = ""
	_transition.entry_tag = ""
	_transition.entry_match = null

func _finish()->void:
	RunSave.delete_file()
	_home.delete_resource()
	_home.resource_name = _home_name
	print("run_save_check: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _frames(count:int)->void:
	for i:int in count:
		await get_tree().physics_frame
