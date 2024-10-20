@tool
extends RichTextLabel


@export var mimicked_paragraph_spacing_font_size: int = 6


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	custom_minimum_size.x = 500
	resized.connect(__on_resized)


func _notification(what) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			__take_over_label_style()


func mimic_paragraphs() -> void:
	var what_in_order: PackedStringArray = [
		"[/p]\n[p]",
		"[/p][p]",
		"[p][/p]",
		"[p]",
		"[/p]",
	]
	var forwhat = "\n[font_size=%s]\n[/font_size]\n" % mimicked_paragraph_spacing_font_size
	var new_text := text
	new_text = new_text.trim_prefix("[p]").trim_suffix("[/p]")
	for what in what_in_order:
		new_text = new_text.replace(what, forwhat)
	new_text = new_text.trim_prefix("\n").trim_suffix("\n")
	text = new_text


func __take_over_label_style() -> void:
	add_theme_stylebox_override(&"normal", get_theme_stylebox(&"normal", &"Label"))


func __on_resized() -> void:
	# Reduce width if unnecessary, as there is no line wraps
	var stylebox = get_theme_stylebox(&"normal")
	var required_width = get_content_width() + stylebox.content_margin_left + stylebox.content_margin_right
	if required_width < custom_minimum_size.x:
		custom_minimum_size.x = required_width
