extends Node

var keyframes:Dictionary = {}
var cached_frames:Array = []
var current_frame:int = 0

func _ready():
	pause_mode = PAUSE_MODE_PROCESS

func advance_frame():
	# Get all time-managed nodes
	var timed_nodes = get_tree().get_nodes_in_group("timed")

	# This is a new frame
	if cached_frames.size() <= current_frame:
		# Instantiate new frame container
		var current_cached_state
		current_cached_state = {}
		cached_frames.append(current_cached_state)

		for node in timed_nodes:
			if node.has_method("get_state"):
				var path = node.get_path()
				current_cached_state[path] = node.get_state()
	
	current_frame += 1

func cut_cached_frames(frame:int, clear_keyframes:bool = false):
	# remove cached frames after {frame}
	cached_frames.resize(frame+1)
	if clear_keyframes:
		for keyframe_frame in keyframes:
			if keyframe_frame > frame:
				# Maybe use erase rather than just nullifying
				# B: Prevent hashmap size adjustment
				keyframes[keyframe_frame] = null

func seek(frame:int):
	var current_cached_state = cached_frames[frame]
	if current_cached_state:
		for node_path in current_cached_state:
			var node = get_node(node_path)
			var state = current_cached_state[node_path]
			if node.has_method("apply_state"):
				node.apply_state(state)
	current_frame = frame

func _physics_process(delta):
	if cached_frames.size() < 253:
		get_tree().paused = false
		advance_frame()
	else:
		get_tree().paused = true

func _unhandled_input(event):
	var seek_speed = 10
	if event.is_action_pressed("ui_left", true):
		yield(get_tree(), "physics_frame")
		seek(max(current_frame-seek_speed, 0))
	
	if event.is_action_pressed("ui_right", true):
		yield(get_tree(), "physics_frame")
		seek(min(current_frame+seek_speed, cached_frames.size()-1))

	if event.is_action_pressed("ui_accept"):
		cut_cached_frames(current_frame)
