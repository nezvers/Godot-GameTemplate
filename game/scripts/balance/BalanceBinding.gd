## Pulls this scene's tunables from the Balance autoload (balance.json).
##
## Place it as a direct child of the scene root. The entry is looked up by the
## root's scene file, so scenes inheriting this one resolve to their own entry,
## and scenes without an entry are left untouched. Values are written on the
## root's tree_entered, which fires before any child's _enter_tree or _ready.
class_name BalanceBinding
extends Node

## Optional explicit entry ("enemies.zombie"); empty looks it up by scene path.
@export var key:String

## Use the scene that owns the root instead of the root's own scene, e.g. the
## room that instances the shared enemy_manager.tscn.
@export var use_owner_scene:bool

## Pooled scenes re-enter the tree; their values are already in place.
var _applied:bool

func _notification(what:int)->void:
	if what != NOTIFICATION_PARENTED:
		return
	var _root:Node = get_parent()
	if !_root.tree_entered.is_connected(_on_root_entered):
		_root.tree_entered.connect(_on_root_entered)

func _on_root_entered()->void:
	if _applied:
		return
	_applied = true
	var _root:Node = get_parent()
	var _base:Node = _root.owner if use_owner_scene && _root.owner != null else _root
	Balance.apply_scene(_base, _base.scene_file_path, key)
