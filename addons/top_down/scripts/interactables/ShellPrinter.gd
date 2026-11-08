## Home base robot printer (CO-OP tree). With Robot Printer bought it prints an
## electrician shell: the shell stays in the bay (HomeBaseResource) and lets this
## player join any host as an electrician (GuestTier), bringing its loot home.
## With Electrician Bay (host side: every guest is an electrician) the same
## machine stands ready with a shell for guests. Hidden with neither upgrade.
##
## In a host's home base (co-op guest) it shows the host's machine: there when the
## host has Electrician Bay, nothing to print.
class_name ShellPrinter
extends Interactable

## Frames of robot_printer_32x32_strip5.png
const FRAME_IDLE:int = 0
const FRAME_READY:int = 4
const PRINT_FRAMES:Array[int] = [1, 2, 3]
const HOME_BASE_PATH:String = "res://game/resources/home_base_resource.tres"

@export var sprite:Sprite2D

var printing:bool
var _print_left:float
var _home_base:HomeBaseResource

func _ready()->void:
	super._ready()
	_home_base = load(HOME_BASE_PATH)
	Net.roster_changed.connect(_refresh)
	_refresh()

func _exit_tree()->void:
	super._exit_tree()
	if Net.roster_changed.is_connected(_refresh):
		Net.roster_changed.disconnect(_refresh)

## Standing in someone else's home base (co-op guest).
func in_host_base()->bool:
	return Net.is_guest()

func can_print()->bool:
	return !in_host_base() && GuestTier.can_print_shell()

func has_shell()->bool:
	return !in_host_base() && _home_base.electrician_shell

## This home base takes every guest in as an electrician.
func bay_open()->bool:
	return Net.host_bay if in_host_base() else GuestTier.host_grants_electricians()

func _refresh()->void:
	visible = can_print() || bay_open()
	set_process(visible || printing)
	area.monitoring = visible
	if !printing && sprite != null:
		sprite.frame = FRAME_READY if has_shell() || bay_open() else FRAME_IDLE

func _process(delta:float)->void:
	super._process(delta)
	if !printing:
		return
	_print_left -= delta
	var _total:float = print_time()
	var _done:float = clampf(1.0 - _print_left / _total, 0.0, 0.999)
	sprite.frame = PRINT_FRAMES[int(_done * PRINT_FRAMES.size())]
	if _print_left <= 0.0:
		finish_print()

static func print_time()->float:
	return maxf(float(Balance.value("coop.shell_print_time", 6.0)), 0.1)

func _can_use()->bool:
	return can_print() && !has_shell() && !printing

func _use()->void:
	printing = true
	busy = true
	_print_left = print_time()
	set_process(true)

func finish_print()->void:
	printing = false
	busy = false
	_home_base.electrician_shell = true
	_home_base.save_resource()
	_refresh()

func _prompt_text()->String:
	if printing:
		return "Printing electrician shell... %d%%" % roundi(100.0 * (1.0 - _print_left / print_time()))
	if has_shell():
		return "Electrician shell ready - join a host as an electrician"
	if can_print():
		return "Print electrician shell"
	return "Guests join as electricians"
