@tool
extends RefCounted

## A filter configuration for searching tasks.


var text: String
## Whether to search in descriptions.
var advanced: bool


func _init(p_text: String = "", p_advanced: bool = false) -> void:
	text = p_text
	advanced = p_advanced
