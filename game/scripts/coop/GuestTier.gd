## How a co-op guest takes part. Every guest is a ghost by default: faint in the
## host's home base and keeping nothing it finds (no weapons go home after a
## victory, boss crystals collected in the session are taken back when it ends).
## An electrician brings its loot home like the host does. A guest is an
## electrician when the host owns Electrician Bay (CO-OP tree) or the guest
## printed an electrician shell (Robot Printer, ShellPrinter).
##
## The host decides at the handshake (Net._hello); the tier travels in the roster.
## On missions both tiers look the same.
class_name GuestTier
extends RefCounted

const META_PATH:String = "res://game/resources/meta_upgrade_resource.tres"
const HOME_BASE_PATH:String = "res://game/resources/home_base_resource.tres"
const CRYSTALS_PATH:String = "res://addons/top_down/resources/global_resources/boss_crystal_resource.tres"
const HOME_SCENE:String = "res://game/scenes/room_H00.tscn"
## A ghost-tier guest in the host's home base.
const GHOST_ALPHA:float = 0.4

## Guest of this session as a ghost: the crystal count to go back to.
static var _held_crystals:int = -1

## Host: every guest joins us as an electrician (Electrician Bay).
static func host_grants_electricians()->bool:
	return (load(META_PATH) as MetaUpgradeResource).stat("guest_electricians") > 0.0

## Guest: this install unlocked the robot printer (Robot Printer).
static func can_print_shell()->bool:
	return (load(META_PATH) as MetaUpgradeResource).stat("shell_printer") > 0.0

## Guest: an electrician shell is printed and waiting.
static func has_shell()->bool:
	return (load(HOME_BASE_PATH) as HomeBaseResource).electrician_shell

## Host: the tier for a guest that says it has a shell.
static func decide(guest_has_shell:bool)->bool:
	return host_grants_electricians() || guest_has_shell

## Guest, joined (or back from its own home base) with this tier.
static func enter(electrician:bool)->void:
	RunSession.local_player().electrician = electrician
	if electrician:
		_release()
		return
	var _crystals:ScoreResource = load(CRYSTALS_PATH)
	if _held_crystals < 0:
		_held_crystals = _crystals.value
	# collected crystals still count up on screen, they just aren't kept
	_crystals.not_saved = true

## Guest leaving the host's game (offline or off to its own home base): what a
## ghost collected goes away.
static func leave()->void:
	_release()

static func _release()->void:
	if _held_crystals < 0:
		return
	var _crystals:ScoreResource = load(CRYSTALS_PATH)
	_crystals.not_saved = false
	_crystals.value = _held_crystals
	_crystals.updated.emit()
	_held_crystals = -1

## A ghost-tier guest's victory weapons don't join its stash.
static func keeps_loot()->bool:
	return !Net.is_guest() || RunSession.local_player().electrician

## How solid a player is drawn: ghost-tier guests are faint in the host's home base.
static func alpha(state:PlayerState)->float:
	if state == null || state.slot == 0 || state.electrician || state.hidden:
		return 1.0
	if !Net.is_online():
		return 1.0
	var _tree:SceneTree = Engine.get_main_loop() as SceneTree
	var _scene:Node = _tree.current_scene if _tree != null else null
	return GHOST_ALPHA if _scene != null && _scene.scene_file_path == HOME_SCENE else 1.0
