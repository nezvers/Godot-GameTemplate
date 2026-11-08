## A second copy of the game on the host's own computer joins as a blank guest:
## it shares the host's user:// folder, so it must neither carry the host's
## progress nor write a single save file.
##
## Net decides it on the host (same machine id, same data folder, local address)
## and says so in _welcome; the guest then calls enter(). The lock lasts until
## the game quits: unlocking later would let both copies write the same files.
class_name GuestSandbox
extends RefCounted

## Progress that belongs to the host's install (settings stay as loaded).
const PROGRESS_PATHS:PackedStringArray = [
	"res://addons/top_down/resources/global_resources/boss_crystal_resource.tres",
	"res://game/resources/campaign_resource.tres",
	"res://game/resources/meta_upgrade_resource.tres",
	"res://game/resources/home_base_resource.tres",
]
const SALT:String = "zs-coop"

## Tests: a client process standing in for another computer sets this, so it
## isn't taken for a second copy of the host's install.
static var install_override:String

static func active()->bool:
	return SaveableResource.persist_locked

## Identifies this computer without sending anything readable.
static func machine_id()->String:
	return (OS.get_unique_id() + SALT).sha256_text()

## Identifies this install's save folder. A dedicated server keeps its saves in
## a folder of its own (--save-dir), so a player on the same computer joining it
## is not a second copy of the server: it keeps its own progress.
static func data_dir_id()->String:
	return (ProjectSettings.globalize_path(SaveableResource.save_dir) + install_override + SALT).sha256_text()

## Guest side: lock saving and forget the host's progress in memory.
static func enter(profile_id:String, display_name:String)->void:
	SaveableResource.persist_locked = true
	for _path:String in PROGRESS_PATHS:
		var _resource:SaveableResource = load(_path)
		_resource.reset_resource()
		_resource.is_loaded = true
	RunSession.active = false
	var _local:PlayerState = RunSession.local_player()
	_local.reset()
	_local.profile_id = profile_id
	_local.display_name = display_name

## Host side: is a guest with these ids at this address this very install?
static func is_same_install(address:String, machine:String, data_dir:String)->bool:
	return is_local_address(address) && machine == machine_id() && data_dir == data_dir_id()

static func is_local_address(address:String)->bool:
	var _address:String = address.strip_edges()
	if _address.begins_with("::ffff:"):
		_address = _address.substr(7)
	if _address == "127.0.0.1" || _address == "::1" || _address.begins_with("127."):
		return true
	return IP.get_local_addresses().has(_address)
