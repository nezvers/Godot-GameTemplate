@tool
extends "kanban_resource.gd"

## Data of a task.


const __Step := preload("step.gd")

var title: String:
	set(value):
		title = value
		__notify_changed()

var description: String:
	set(value):
		description = value
		__notify_changed()

var category: String:
	set(value):
		category = value
		__notify_changed()

var steps: Array[__Step]:
	get:
		return steps.duplicate()
	set(value):
		steps = value
		__notify_changed()


func _init(p_title: String = "", p_description: String = "", p_category: String = "", p_steps: Array[__Step] = []) -> void:
	title = p_title
	description = p_description
	category = p_category
	steps = p_steps
	super._init()


func add_step(step: __Step, silent: bool = false) -> void:
	var new_steps = steps
	new_steps.append(step)
	steps = new_steps
	step.changed.connect(__notify_changed)
	if not silent:
		__notify_changed()


func to_json() -> Dictionary:
	var s: Array[Dictionary] = []
	for step in steps:
		s.append(step.to_json())

	return {
		"title": title,
		"description": description,
		"category": category,
		"steps": s,
	}


func from_json(json: Dictionary) -> void:
	if json.has("title"):
		title = json["title"]
	else:
		push_warning("Loading incomplete json data which is missing a title.")

	if json.has("description"):
		description = json["description"]
	else:
		push_warning("Loading incomplete json data which is missing a description.")

	if json.has("category"):
		category = json["category"]
	else:
		push_warning("Loading incomplete json data which is missing a category.")

	if json.has("steps"):
		var s: Array[__Step] = []
		for step in json["steps"]:
			s.append(__Step.new())
			s[-1].from_json(step)
			s[-1].changed.connect(__notify_changed)
		steps = s
	else:
		push_warning("Loading incomplete json data which is missing steps.")
