extends Node

## Pressing this the game will pause or move one frame
## WARNING: Physics nodes have settings about stopped processing
@export var frame_input:InputEvent
## Hold this and press frame input to release
@export var release_input:InputEvent
## Node which process_mode will be affected
@export var stopped_node:Node

## Action Name for one frame pause input
const frame_action:StringName = "DebugPauseFrame"
## Action Name for release input
const release_action:StringName = "DebugPauseRelease"

## Inner state, if enabled the processing is stopped and allowed to move by one frame
var enabled:bool
## State when waiting for one frame
var waiting_frame:bool = false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	if !InputMap.has_action(frame_action):
		InputMap.add_action(frame_action)
		InputMap.action_add_event(frame_action, frame_input)
	
	if !InputMap.has_action(release_action):
		InputMap.add_action(release_action)
		InputMap.action_add_event(release_action, release_input)

func _input(event:InputEvent)->void:
	# Ignore if not the frame input
	if !event.is_action_pressed(frame_action):
		return
	
	# Release input is held?
	if Input.is_action_pressed(release_action) && enabled:
		set_enabled(false)
		return
	
	if !enabled:
		set_enabled(true)
		return
	
	if waiting_frame:
		return
	
	set_waiting_frame(true)


func set_enabled(value:bool)->void:
	enabled = value
	if enabled:
		stopped_node.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		stopped_node.process_mode = Node.PROCESS_MODE_INHERIT

## Allow one frame to pass and stop on second frame
func set_waiting_frame(value:bool)->void:
	waiting_frame = value
	
	if !enabled:
		return
	
	if waiting_frame:
		stopped_node.process_mode = Node.PROCESS_MODE_INHERIT
		get_tree().physics_frame.connect(frame_delay, CONNECT_ONE_SHOT)
	else:
		stopped_node.process_mode = Node.PROCESS_MODE_DISABLED

## Called one frame later to set stopping again
func frame_delay()->void:
	get_tree().physics_frame.connect(set_waiting_frame.bind(false), CONNECT_ONE_SHOT)
