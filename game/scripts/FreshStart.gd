## Starts a new run when room_start is loaded from the title, game over or
## victory screen. Walking back in through a door keeps the run: PlayerSpawner
## clears next_scene_path once a door arrival is placed, so a value naming this
## room means the carried player is arriving right now.
##
## On a new run any carried player/transition state is stale and must be reset
## BEFORE PlayerSpawner._ready runs — otherwise PlayerSpawner sees a lingering
## player_reference and tries the door-entry path (which needs an entry_match
## that doesn't exist here), leaving the player unplaced or outside the room.
##
## Runs in _enter_tree so it executes before any sibling/parent _ready.
extends Node

## Carried player reference (cleared on the player node's tree_exiting).
@export var player_reference: ReferenceNodeResource

## Transition state carried between rooms.
@export var scene_transition_resource: SceneTransitionResource

## Campaign start rooms remember themselves here, so Try Again / Play Again
## restart the same campaign. Optional.
@export var campaign_resource: CampaignResource

## Run-scoped state (score/coins, meat, slime, weapon upgrades, weapon inventory)
## reset for the new run. Each entry needs a reset_resource() method.
@export var run_resources: Array[Resource]

## Meta-upgrades that start the run with items (global, so the generated rooms need no export).
const META_UPGRADES: MetaUpgradeResource = preload("res://game/resources/meta_upgrade_resource.tres")

## The one weapon carried out of the home base (HomeBase.depart) joins the run here.
const HOME_BASE: HomeBaseResource = preload("res://game/resources/home_base_resource.tres")
const WEAPON_INVENTORY: ItemCollectionResource = preload("res://addons/top_down/resources/ItemCollectionResource/weapon_inventory.tres")
const WEAPON_DATABASE: ItemCollectionResource = preload("res://addons/top_down/resources/ItemCollectionResource/weapon_database.tres")

## Loot item id -> meta stat giving that many at the start of a run.
const START_ITEMS: Dictionary = {"coin": "start_coin", "meat": "start_meat", "slime": "start_slime"}

func _enter_tree() -> void:
	assert(player_reference != null)
	assert(scene_transition_resource != null)

	if campaign_resource != null and owner != null:
		campaign_resource.start_scene = owner.scene_file_path

	# A door arrival names this room. The victory exit is a portal too, so after it
	# next_scene_path still holds the victory screen with the player carried along.
	var carried: Node = player_reference.node
	if _is_arrival() and is_instance_valid(carried):
		return

	# Continue: RunSession already restored the saved run; the spawner places it.
	if RunSession.is_resuming():
		return

	# Free any stale, detached player from a previous run so PlayerSpawner spawns
	# a fresh one at its marker.
	if carried != null:
		player_reference.remove_reference(carried)
		if is_instance_valid(carried) and carried.get_parent() == null:
			carried.queue_free()

	# Clear transition info so PlayerSpawner takes the fresh-spawn branch.
	scene_transition_resource.next_scene_path = ""
	scene_transition_resource.entry_tag = ""
	scene_transition_resource.entry_match = null

	for resource: Resource in run_resources:
		if resource != null:
			resource.reset_resource()
	RunSession.start_new_run()

	for item: String in START_ITEMS:
		var amount: int = int(META_UPGRADES.stat(START_ITEMS[item]))
		if amount > 0:
			LootItems.counter(item).add(amount)

	_hand_over_loadout()

## Gives the gun brought from the home base; it is used up by this run.
func _hand_over_loadout() -> void:
	var home: HomeBaseResource = HOME_BASE
	if home.loadout.is_empty():
		return
	var weapon: ItemResource = HomeBaseResource.find_item(WEAPON_DATABASE, home.loadout)
	home.loadout = ""
	home.save_resource()
	if weapon != null:
		WEAPON_INVENTORY.append(weapon)

func _is_arrival() -> bool:
	var next: String = scene_transition_resource.next_scene_path
	if next.is_empty():
		return false
	if owner == null or owner.scene_file_path.is_empty():
		return true
	return next == owner.scene_file_path
