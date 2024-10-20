@tool
extends Node

## Global stuff for the view system.


const __Filter := preload("filter.gd")
const __SettingData := preload("../data/settings.gd")

signal filter_changed()
signal save_board()
signal create_board()
signal reload_board()

## The currently active filter.
var filter: __Filter = null:
	set(value):
		filter = value
		filter_changed.emit()

## The undo redo for task operations.
var undo_redo := UndoRedo.new()

## uuid of the object that should have focus. This is used to persist focus
## when updating some views.
var focus: String = ""

## Settings that are not tied to the board.
var settings := __SettingData.new()
