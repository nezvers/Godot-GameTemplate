## Mid-run checkpoint, written at room arrival and on section/room clears and
## read by the title's Continue. user://RunSave.tres; deleted when the run ends
## (game over, victory, home base, new run) so it can't be reloaded for loot.
##
## Extending: shared run state goes in a RunSaveComponent subclass (components),
## per-player state in PlayerRunData. Bump FORMAT_VERSION and handle the old
## layout in _migrate() when a field changes meaning.
class_name RunSave
extends SaveableResource

const FORMAT_VERSION:int = 1
## Save file base name; tests switch it so a real save is never touched.
static var file_name:String = "RunSave"

enum Mode {SINGLE, COOP_HOST}

@export var format_version:int = FORMAT_VERSION
## ProjectSettings application/config/version when written.
@export var game_version:String
@export var saved_at_unix:int
@export var mode:Mode = Mode.SINGLE
## Start room of the run (New Game / New Game+), for Try Again / Play Again.
@export var campaign_start_scene:String
## Checkpoint room and the door the party arrived through ("" = the room's spawn marker).
@export var room_scene:String
@export var entry_tag:String
@export var players:Array[PlayerRunData]
@export var components:Array[RunSaveComponent]

func _init()->void:
	resource_name = file_name

func prepare_save()->Resource:
	return self

func get_component(component_id:StringName)->RunSaveComponent:
	for _component:RunSaveComponent in components:
		if _component != null && _component.id() == component_id:
			return _component
	return null

## A usable save: right format and the checkpoint room still exists.
func is_valid()->bool:
	return format_version >= 1 && format_version <= FORMAT_VERSION \
		&& !room_scene.is_empty() && ResourceLoader.exists(room_scene) && !players.is_empty()

static func file_path()->String:
	return SaveableResource.save_dir.path_join(file_name + ".tres")

static func exists()->bool:
	return FileAccess.file_exists(file_path())

static func delete_file()->void:
	if exists() && !SaveableResource.persist_locked:
		DirAccess.remove_absolute(file_path())

## Loads the save, or null when it is missing, unreadable or not a RunSave.
## The text is checked for embedded scripts first: a .tres can carry GDScript
## source, and this file is the one thing a player might be handed by someone else.
static func read()->RunSave:
	var _path:String = file_path()
	if SaveableResource.persist_locked || !FileAccess.file_exists(_path):
		return null
	var _text:String = FileAccess.get_file_as_string(_path)
	if _text.contains("type=\"GDScript\"") || _text.contains("script/source"):
		push_warning("RunSave: rejected save with an embedded script")
		return null
	var _save:RunSave = ResourceLoader.load(_path, "", ResourceLoader.CACHE_MODE_IGNORE) as RunSave
	if _save == null:
		return null
	_save._migrate()
	return _save if _save.is_valid() else null

func _migrate()->void:
	# format_version 1 is the first layout; future upgrades go here.
	var _kept:Array[RunSaveComponent] = []
	for _component:RunSaveComponent in components:
		if _component == null:
			continue
		if _component.component_version < _component.current_version():
			_component.migrate(_component.component_version)
			_component.component_version = _component.current_version()
		_kept.append(_component)
	components = _kept
