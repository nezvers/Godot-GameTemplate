## Autoload: the run in progress, its players and its checkpoint (RunSave).
##
## A run starts in a campaign start room (FreshStart -> start_new_run) or from the
## title's Continue (resume). While it is active, a checkpoint is written when the
## party is placed in a room and whenever room progress changes (section/room
## cleared, loot box opened), plus on Pause -> Main Menu and window close.
## Game over and victory end the run and delete the save. Home base and the title
## only suspend it: the save stays for Continue.
extends Node

const TD:String = "res://addons/top_down/"
const ROOM_STATE_PATH:String = TD + "resources/global_resources/room_state_resource.tres"
const TRANSITION_PATH:String = TD + "resources/global_resources/scene_transition_resource.tres"
const CAMPAIGN_PATH:String = "res://game/resources/campaign_resource.tres"
## Run-scoped resources cleared before a resume is applied (same list as FreshStart's).
const RUN_RESOURCE_PATHS:PackedStringArray = [
	TD + "resources/global_resources/score_resource.tres",
	TD + "resources/global_resources/meat_resource.tres",
	TD + "resources/global_resources/slime_resource.tres",
	TD + "resources/global_resources/weapon_upgrade_resource.tres",
	TD + "resources/ItemCollectionResource/weapon_inventory.tres",
	TD + "resources/global_resources/room_state_resource.tres",
]
## Shared run state stored in every checkpoint. New state: one script here.
const COMPONENTS:Array[Script] = [
	preload("res://game/scripts/run/RoomProgressComponent.gd"),
]

signal checkpoint_saved

var profile:PlayerProfile
var players:PlayerRegistry = PlayerRegistry.new()

## A run is in progress and checkpoints are written.
var active:bool
## Set by resume() until the player spawner has placed the resumed party.
var _resume_data:RunSave
var _room:Node
var _room_scene:String
var _entry_tag:String
var _checkpoint_queued:bool
## Host of a continued co-op run: profile id -> saved data of a guest that
## hasn't rejoined yet (handed back by NetPlayers when it does).
var waiting_guests:Dictionary = {}

func _ready()->void:
	# Headless runs are the test suites (they share the real save dir): never
	# touch the player's checkpoint from them.
	if DisplayServer.get_name() == "headless":
		RunSave.file_name = "RunSave_headless"
	# a dedicated server keeps its saves in its own folder (--save-dir)
	DedicatedServer.configure_early()
	profile = PlayerProfile.new()
	profile.load_resource()
	profile.ensure_id()
	players.add(PlayerState.create_local(profile.profile_id, profile.display_name))
	var _room_state:RoomStateResource = load(ROOM_STATE_PATH)
	_room_state.updated.connect(queue_checkpoint)
	get_tree().auto_accept_quit = false

func _notification(what:int)->void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		checkpoint()
		get_tree().quit()

func local_player()->PlayerState:
	return players.local()

func has_save()->bool:
	return RunSave.read() != null

## FreshStart: a new run replaces any saved one.
func start_new_run()->void:
	_resume_data = null
	waiting_guests.clear()
	# a co-op guest plays the host's run: its own solo checkpoint stays as it is
	active = !Net.is_guest()
	if active:
		RunSave.delete_file()

## Game over / victory: nothing left to continue.
func end_run()->void:
	var _was_guest:bool = Net.is_guest()
	Net.players.on_run_ended()
	active = false
	_resume_data = null
	_room = null
	if !_was_guest:
		RunSave.delete_file()

## Home base / title: stop checkpointing, keep the save for Continue.
func suspend()->void:
	active = false
	_room = null

func is_resuming()->bool:
	return _resume_data != null

## Title Continue: restores the run and loads its checkpoint room.
func resume()->bool:
	var _save:RunSave = RunSave.read()
	if _save == null:
		return false
	apply_save(_save)
	Transition.change_scene(_save.room_scene)
	return true

## Restores the run state from a save; the room then spawns the party at the
## saved door (PlayerSpawner -> take_resume_entry / finish_resume).
func apply_save(save:RunSave)->void:
	for _path:String in RUN_RESOURCE_PATHS:
		(load(_path) as Resource).reset_resource()
	for _script:Script in COMPONENTS:
		var _stored:RunSaveComponent = null
		var _probe:RunSaveComponent = _script.new()
		_stored = save.get_component(_probe.id())
		(_stored if _stored != null else _probe).apply()
	waiting_guests.clear()
	for _data:PlayerRunData in save.players:
		var _state:PlayerState = players.find_profile(_data.profile_id)
		if _state == null && _data.slot == 0:
			# single player: slot 0 is always this install, even if the profile was reset
			_state = local_player()
		if _state != null:
			_state.apply(_data)
		else:
			waiting_guests[_data.profile_id] = _data
	var _campaign:CampaignResource = load(CAMPAIGN_PATH)
	if !save.campaign_start_scene.is_empty():
		_campaign.start_scene = save.campaign_start_scene
	var _transition:SceneTransitionResource = load(TRANSITION_PATH)
	_transition.next_scene_path = ""
	_transition.entry_tag = save.entry_tag
	_transition.entry_match = null
	_resume_data = save
	active = true

## PlayerSpawner, spawning a resumed party: the door to place it at ("" = marker).
func resume_entry_tag()->String:
	return _resume_data.entry_tag if _resume_data != null else ""

## PlayerSpawner, once the resumed player is in the tree: hp goes back last,
## after Balance and MetaStats have reset it.
func finish_resume(player:Node)->void:
	var _save:RunSave = _resume_data
	_resume_data = null
	if _save == null:
		return
	for _data:PlayerRunData in _save.players:
		var _state:PlayerState = players.find_profile(_data.profile_id)
		if _state == null && _data.slot == 0:
			_state = local_player()
		if _state != null && _state.is_local:
			_state.apply_health(_data)
	players.set_node(players.local_slot, player)

## PlayerSpawner: the party is in `room`, arrived through `entry_tag`.
func on_party_placed(room:Node, entry_tag:String)->void:
	if room == null || room.scene_file_path.is_empty():
		return
	_room = room
	_room_scene = room.scene_file_path
	_entry_tag = entry_tag
	if !room.tree_exiting.is_connected(_on_room_exiting):
		room.tree_exiting.connect(_on_room_exiting.bind(room), CONNECT_ONE_SHOT)
	checkpoint()

func _on_room_exiting(room:Node)->void:
	if _room == room:
		_room = null

func queue_checkpoint()->void:
	if !active || _checkpoint_queued:
		return
	_checkpoint_queued = true
	_deferred_checkpoint.call_deferred()

func _deferred_checkpoint()->void:
	_checkpoint_queued = false
	checkpoint()

## Writes the checkpoint if a run is active and its room is loaded.
func checkpoint()->bool:
	if !active || Net.is_guest() || SaveableResource.persist_locked || !is_instance_valid(_room) || !_room.is_inside_tree():
		return false
	var _save:RunSave = capture()
	var _err:int = ResourceSaver.save(_save, RunSave.file_path())
	if _err != OK:
		push_warning("RunSession: checkpoint failed (%d)" % _err)
		return false
	checkpoint_saved.emit()
	return true

func capture()->RunSave:
	var _save:RunSave = RunSave.new()
	_save.game_version = str(ProjectSettings.get_setting("application/config/version", ""))
	_save.saved_at_unix = int(Time.get_unix_time_from_system())
	_save.mode = RunSave.Mode.COOP_HOST if Net.is_host() && players.count() > 1 else RunSave.Mode.SINGLE
	var _campaign:CampaignResource = load(CAMPAIGN_PATH)
	_save.campaign_start_scene = _campaign.restart_scene()
	_save.room_scene = _room_scene
	_save.entry_tag = _entry_tag
	for _state:PlayerState in players.all():
		# a ghost that left at victory has no part in this run; the hidden
		# server player isn't one of the party
		if _state.hidden || (_state.ghost && !_state.parked):
			continue
		_save.players.append(_state.capture())
	# guests of a continued co-op run who haven't rejoined keep their place
	for _profile:String in waiting_guests:
		if players.find_profile(_profile) == null:
			_save.players.append(waiting_guests[_profile])
	for _script:Script in COMPONENTS:
		var _component:RunSaveComponent = _script.new()
		_component.component_version = _component.current_version()
		_component.capture()
		_save.components.append(_component)
	return _save
