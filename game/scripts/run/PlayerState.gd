## One player's live run state: health, weapons, weapon upgrades and wallet.
## The local player's state points at the shared global resources the player
## scene and HUD already use (player_health, weapon_inventory, ...), so single
## player behaves exactly as before. Other co-op players get their own copies
## (PlayerState.create_remote), injected into their player node at spawn.
class_name PlayerState
extends RefCounted

## Remote players: a network update changed hp, weapon, room or downed.
signal net_updated

const TD:String = "res://addons/top_down/"
const HEALTH_PATH:String = TD + "resources/health_resource/player_health.tres"
const INVENTORY_PATH:String = TD + "resources/ItemCollectionResource/weapon_inventory.tres"
const UPGRADES_PATH:String = TD + "resources/global_resources/weapon_upgrade_resource.tres"
const DATABASE_PATH:String = TD + "resources/ItemCollectionResource/weapon_database.tres"
## Run wallet items; boss crystals are meta progress and stay out of it.
const WALLET_ITEMS:PackedStringArray = ["coin", "meat", "slime"]

var profile_id:String
var display_name:String
var slot:int
## Multiplayer peer id while connected (1 = host / offline).
var peer_id:int = 1
var is_local:bool
var downed:bool

var health:HealthResource
var inventory:ItemCollectionResource
var weapon_levels:WeaponUpgradeResource
## Loot item id -> ScoreResource
var wallet:Dictionary

## Mirrored from the network for remote players (PlayerNetSync): the room scene
## they are in and the name of the weapon in their hands ("" = fists).
var room_scene:String
var weapon_name:String
## 0..1 while a teammate stands by this downed player.
var revive_progress:float
## Holding the revive key next to a downed teammate (ReviveAssist).
var reviving:bool
## A guest who went to its own home base with "I will return": the seat is
## kept, a faint copy walks the host's home base (ghost_room is where it is).
var ghost:bool
var ghost_room:String
## Host: that ghost left mid-run; its guest_run_data waits for it to come back.
var parked:bool
## Back from a ghost into a fight: standing at the door until the walls drop.
var waiting:bool
## The dedicated server's own player: invisible, never hurt, never counted.
var hidden:bool
## Co-op guest tier (GuestTier): an electrician brings its loot home, a ghost
## (the default) is faint in the host's home base and keeps nothing.
var electrician:bool

## Takes part in the fight: counted for scaling, revives and the wipe.
func is_active()->bool:
	return !ghost && !waiting && !hidden

## Host: a guest's own run state as it last sent it (NetPlayers), saved in the
## co-op checkpoint in place of this copy's partial view.
var guest_run_data:PlayerRunData

static func create_local(id:String, name:String)->PlayerState:
	var _state:PlayerState = PlayerState.new()
	_state.profile_id = id
	_state.display_name = name
	_state.is_local = true
	_state.health = load(HEALTH_PATH)
	_state.inventory = load(INVENTORY_PATH)
	_state.weapon_levels = load(UPGRADES_PATH)
	for _item:String in WALLET_ITEMS:
		_state.wallet[_item] = LootItems.counter(_item)
	return _state

## A co-op teammate: same templates, own copies.
static func create_remote(id:String, name:String, slot_index:int)->PlayerState:
	var _state:PlayerState = PlayerState.new()
	_state.profile_id = id
	_state.display_name = name
	_state.slot = slot_index
	_state.health = (load(HEALTH_PATH) as HealthResource).duplicate()
	_state.inventory = (load(INVENTORY_PATH) as ItemCollectionResource).duplicate()
	_state.inventory.list = []
	_state.weapon_levels = WeaponUpgradeResource.new()
	for _item:String in WALLET_ITEMS:
		var _counter:ScoreResource = (LootItems.counter(_item) as ScoreResource).duplicate()
		_counter.reset_resource()
		_state.wallet[_item] = _counter
	return _state

func capture()->PlayerRunData:
	if guest_run_data != null:
		var _copy:PlayerRunData = guest_run_data.duplicate()
		_copy.profile_id = profile_id
		_copy.display_name = display_name
		_copy.slot = slot
		_copy.downed = downed
		return _copy
	var _data:PlayerRunData = PlayerRunData.new()
	_data.profile_id = profile_id
	_data.display_name = display_name
	_data.slot = slot
	_data.hp = health.hp
	_data.max_hp = health.max_hp
	_data.downed = downed
	var _names:PackedStringArray = []
	for _item:ItemResource in inventory.list:
		if _item != null:
			_names.append(_item.resource_name)
	_data.weapons = _names
	_data.selected = inventory.selected
	_data.weapon_levels = weapon_levels.levels.duplicate()
	for _item:String in wallet:
		var _counter:ScoreResource = wallet[_item]
		_data.wallet[_item] = {"value": _counter.value, "collected_total": _counter.collected_total}
	return _data

## Restores everything but hp, which the player node resets on spawn
## (Balance + MetaStats); apply_health() runs once it is in the tree.
func apply(data:PlayerRunData)->void:
	profile_id = data.profile_id if !data.profile_id.is_empty() else profile_id
	display_name = data.display_name if !data.display_name.is_empty() else display_name
	slot = data.slot
	downed = data.downed
	var _database:ItemCollectionResource = load(DATABASE_PATH)
	var _list:Array[ItemResource] = []
	for _name:String in data.weapons:
		var _item:ItemResource = HomeBaseResource.find_item(_database, _name)
		if _item != null:
			_list.append(_item)
	inventory.set_list(_list)
	inventory.set_selected(clampi(data.selected, 0, maxi(_list.size() - 1, 0)))
	weapon_levels.levels = data.weapon_levels.duplicate()
	weapon_levels.updated.emit()
	for _item:String in wallet:
		var _counter:ScoreResource = wallet[_item]
		var _entry:Dictionary = data.wallet.get(_item, {})
		_counter.value = int(_entry.get("value", 0))
		_counter.collected_total = int(_entry.get("collected_total", 0))
		_counter.updated.emit()

## Name of the weapon in hand ("" = fists), read from the inventory.
func active_weapon_name()->String:
	var _item:ItemResource = active_weapon()
	return _item.resource_name if _item != null else ""

func active_weapon()->ItemResource:
	if inventory == null || inventory.list.is_empty():
		return null
	return inventory.list[clampi(inventory.selected, 0, inventory.list.size() - 1)]

func apply_health(data:PlayerRunData)->void:
	if data.hp <= 0.0:
		return
	health.hp = clampf(data.hp, 1.0, health.max_hp)
	health.hp_changed.emit()

## A new run: empty hands, empty wallet, no upgrades.
func reset()->void:
	downed = false
	inventory.reset_resource()
	weapon_levels.reset_resource()
	for _item:String in wallet:
		(wallet[_item] as ScoreResource).reset_resource()
