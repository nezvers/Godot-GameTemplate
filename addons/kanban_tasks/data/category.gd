@tool
extends "kanban_resource.gd"

## Data of a category.


var title: String:
	set(value):
		title = value
		__notify_changed()

var color: Color:
	set(value):
		color = value
		__notify_changed()


func _init(p_title: String = "", p_color: Color = Color()) -> void:
	title = p_title
	color = p_color
	super._init()


func to_json() -> Dictionary:
	return {
		"title": title,
		"color": color.to_html(false),
	}


func from_json(json: Dictionary) -> void:
	title = "Missing data."
	color = Color.CORNFLOWER_BLUE

	if json.has("title"):
		title = json["title"]
	else:
		push_warning("Loading incomplete json data which is missing a title.")

	if json.has("color"):
		color = Color.html(json["color"])
	else:
		push_warning("Loading incomplete json data which is missing a color.")
