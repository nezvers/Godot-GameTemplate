## Title Continue: shown while a run checkpoint (RunSave) exists, resumes it.
extends Node

@export var button:Button
## The menu button (PanelContainer) to show or hide.
@export var entry:Control

func _ready()->void:
	# The title isn't part of a run; a checkpoint left behind stays for Continue.
	RunSession.suspend()
	var _has_save:bool = RunSession.has_save()
	entry.visible = _has_save
	if !_has_save:
		return
	button.pressed.connect(_on_pressed, CONNECT_ONE_SHOT)
	# after MenuTraverseManager focused New Game (deferred)
	await get_tree().process_frame
	if is_instance_valid(button) && button.is_visible_in_tree():
		button.grab_focus()

func _on_pressed()->void:
	if !RunSession.resume():
		entry.visible = false
