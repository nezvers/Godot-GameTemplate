@tool
extends Node


var delete := Shortcut.new()
var duplicate := Shortcut.new()
var create := Shortcut.new()
var rename := Shortcut.new()
var search := Shortcut.new()
var confirm := Shortcut.new()
var undo := Shortcut.new()
var redo := Shortcut.new()

var save := Shortcut.new()
var save_as := Shortcut.new()


## Returns whether a specific node should handle the shortcut.
static func should_handle_shortcut(node: Node) -> bool:
	var focus_owner := node.get_viewport().gui_get_focus_owner()
	return focus_owner and (node.is_ancestor_of(focus_owner) or focus_owner == node)


func _ready() -> void:
	__setup_shortcuts()


func __setup_shortcuts() -> void:
	# delete
	var ev_delete := InputEventKey.new()
	if OS.get_name() == "macOS":
		ev_delete.keycode = KEY_BACKSPACE
		ev_delete.meta_pressed = true
	else:
		ev_delete.keycode = KEY_DELETE
	delete.events.append(ev_delete)

	# duplicate
	var ev_dupe := InputEventKey.new()
	if OS.get_name() == "macOS":
		ev_dupe.keycode = KEY_D
		ev_dupe.meta_pressed = true
	else:
		ev_dupe.keycode = KEY_D
		ev_dupe.ctrl_pressed = true
	duplicate.events.append(ev_dupe)

	# create
	var ev_create := InputEventKey.new()
	if OS.get_name() == "macOS":
		ev_create.keycode = KEY_A
		ev_create.meta_pressed = true
	else:
		ev_create.keycode = KEY_A
		ev_create.ctrl_pressed = true
	create.events.append(ev_create)

	# rename
	var ev_rename := InputEventKey.new()
	ev_rename.keycode = KEY_F2
	rename.events.append(ev_rename)

	# search
	var ev_search := InputEventKey.new()
	if OS.get_name() == "macOS":
		ev_search.keycode = KEY_F
		ev_search.meta_pressed = true
	else:
		ev_search.keycode = KEY_F
		ev_search.ctrl_pressed = true
	search.events.append(ev_search)

	# confirm
	var ev_confirm := InputEventKey.new()
	ev_confirm.keycode = KEY_ENTER
	confirm.events.append(ev_confirm)

	# undo
	var ev_undo := InputEventKey.new()
	if OS.get_name() == "macOS":
		ev_undo.keycode = KEY_Z
		ev_undo.meta_pressed = true
	else:
		ev_undo.keycode = KEY_Z
		ev_undo.ctrl_pressed = true
	undo.events.append(ev_undo)

	# redo
	var ev_redo := InputEventKey.new()
	if OS.get_name() == "macOS":
		ev_redo.keycode = KEY_Z
		ev_redo.meta_pressed = true
		ev_redo.shift_pressed = true
	else:
		ev_redo.keycode = KEY_Z
		ev_redo.ctrl_pressed = true
		ev_redo.shift_pressed = true
	redo.events.append(ev_redo)

	# save
	var ev_save := InputEventKey.new()
	if OS.get_name() == "macOS":
		ev_save.keycode = KEY_S
		ev_save.meta_pressed = true
	else:
		ev_save.keycode = KEY_S
		ev_save.ctrl_pressed = true
	save.events.append(ev_save)

	# save as
	var ev_save_as := InputEventKey.new()
	if OS.get_name() == "macOS":
		ev_save_as.keycode = KEY_S
		ev_save_as.meta_pressed = true
		ev_save_as.shift_pressed = true
	else:
		ev_save_as.keycode = KEY_S
		ev_save_as.ctrl_pressed = true
		ev_save_as.shift_pressed = true
	save_as.events.append(ev_save_as)
