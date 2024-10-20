@tool
extends "kanban_resource.gd"

## Contains settings that are not bound to a board.


const DEFAULT_EDITOR_DATA_PATH: String = "res://kanban_tasks_data.kanban"

enum DescriptionOnBoard {
	FULL,
	FIRST_LINE,
	UNTIL_FIRST_BLANK_LINE,
}

enum StepsOnBoard {
	ONLY_OPEN,
	ALL_OPEN_FIRST,
	ALL_IN_ORDER
}

## Whether the first line of the description is shown on the board.
var show_description_preview: bool = true:
	set(value):
		show_description_preview = value
		__notify_changed()

var show_steps_preview: bool = true:
	set(value):
		show_steps_preview = value
		__notify_changed()

var show_category_on_board: bool = false:
	set(value):
		show_category_on_board = value
		__notify_changed()

var edit_step_details_exclusively: bool = false:
	set(value):
		edit_step_details_exclusively = value
		__notify_changed()

var max_displayed_lines_in_description: int = 0:
	set(value):
		max_displayed_lines_in_description = value
		__notify_changed()

var description_on_board := DescriptionOnBoard.FIRST_LINE:
	set(value):
		description_on_board = value
		__notify_changed()

var steps_on_board := StepsOnBoard.ONLY_OPEN:
	set(value):
		steps_on_board = value
		__notify_changed()

var max_steps_on_board: int = 2:
	set(value):
		max_steps_on_board = value
		__notify_changed()

var editor_data_file_path: String = DEFAULT_EDITOR_DATA_PATH:
	set(value):
		editor_data_file_path = value
		__notify_changed()

var warn_about_empty_deletion: bool = false:
	set(value):
		warn_about_empty_deletion = value
		__notify_changed()

var recent_file_count: int = 5:
	set(value):
		recent_file_count = value
		recent_files.resize(value)
		__notify_changed()

var recent_files: PackedStringArray = []:
	get:
		return recent_files.duplicate()
	set(value):
		recent_files = value
		__notify_changed()

# Here such settings can come, which is own responsibiity of a user control.
# When it just want to persist its own state, but the setting is not used by anything else.
# In this case there is no need to mess up this class with bolerplate code
# E.g. the splitter position in the details editor window
# Set via set_internal_state to trigger notification
# (As no clean-up, during develolpment some mess can remain in it.
# Use clear or erase in your code in such cases, just don't forget there)
var internal_states: Dictionary = { }


func set_internal_state(property: String, value: Variant) -> void:
	internal_states[property] = value
	__notify_changed()


func to_json() -> Dictionary:
	var res := {
		"show_description_preview": show_description_preview,
		"warn_about_empty_deletion": warn_about_empty_deletion,
		"edit_step_details_exclusively": edit_step_details_exclusively,
		"max_displayed_lines_in_description": max_displayed_lines_in_description,
		"description_on_board": description_on_board,
		"show_steps_preview": show_steps_preview,
		"show_category_on_board": show_category_on_board,
		"steps_on_board": steps_on_board,
		"max_steps_on_board": max_steps_on_board,
	}

	if not Engine.is_editor_hint():
		res["recent_file_count"] = recent_file_count
		res["recent_files"] = recent_files
	else:
		res["editor_data_file_path"] = editor_data_file_path

	res["internal_states"] = internal_states

	return res


func from_json(json: Dictionary) -> void:
	if json.has("show_description_preview"):
		show_description_preview = json["show_description_preview"]
	if json.has("warn_about_empty_deletion"):
		warn_about_empty_deletion = json["warn_about_empty_deletion"]
	if json.has("edit_step_details_exclusively"):
		edit_step_details_exclusively = json["edit_step_details_exclusively"]
	if json.has("max_displayed_lines_in_description"):
		max_displayed_lines_in_description = json["max_displayed_lines_in_description"]
	if json.has("description_on_board"):
		description_on_board = json["description_on_board"]
	if json.has("editor_data_file_path"):
		editor_data_file_path = json["editor_data_file_path"]
	if json.has("recent_file_count"):
		recent_file_count = json["recent_file_count"]
	if json.has("recent_files"):
		recent_files = PackedStringArray(json["recent_files"])
	if json.has("show_steps_preview"):
		show_steps_preview = json["show_steps_preview"]
	if json.has("steps_on_board"):
		steps_on_board = json["steps_on_board"]
	if json.has("max_steps_on_board"):
		max_steps_on_board = json["max_steps_on_board"]
	if json.has("show_category_on_board"):
		show_category_on_board = json["show_category_on_board"]
	if json.has("internal_states"):
		internal_states = json["internal_states"]
	__notify_changed()
