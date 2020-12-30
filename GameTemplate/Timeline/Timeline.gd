extends Control

export var playing:bool = true setget set_playing
export var max_time:float = 0
export var frame_skip: int = 4

var keyframes:Dictionary = {}
var cached_frames:Array = []
var current_frame:float = 0
var elapsed_time:float = 0.0
var _physics_frames:int = 0

class FrameState extends Reference:
	var time:float
	var nodes:Dictionary
	
	func _init(time:float):
		self.time = time
		nodes = {}

# Setters
func set_playing(value:bool):
	var changed = value != playing
	playing = value
	
	if not playing:
		_physics_frames = 0
	
	if changed:
		Physics2DServer.set_active(playing)
		var timed_nodes = get_tree().get_nodes_in_group("timed")
		for node in timed_nodes:
			if node.has_method("set_playing"):
				node.set_playing(playing)

func _ready():
	pause_mode = PAUSE_MODE_PROCESS
	set_playing(playing)

func capture_frame():

	var qframe:int = floor(current_frame)

	# This is a new frame
	if cached_frames.size() <= qframe:
		# Instantiate new frame container
		var current_cached_state
		current_cached_state = FrameState.new(elapsed_time)
		cached_frames.append(current_cached_state)

		# Get all time-managed nodes
		var timed_nodes = get_tree().get_nodes_in_group("timed")
		for node in timed_nodes:
			if node.has_method("get_state"):
				var path = node.get_path()
				current_cached_state.nodes[path] = node.get_state()

func cut_cached_frames(frame:float, clear_keyframes:bool = false):
	# remove cached frames after {frame}
	var qframe:int = floor(frame)
	cached_frames.resize(min(qframe+1, cached_frames.size()))
	current_frame = qframe
	elapsed_time = cached_frames[cached_frames.size()-1].time
	if clear_keyframes:
		for keyframe_frame in keyframes:
			if keyframe_frame > qframe:
				# Maybe use erase rather than just nullifying
				# B: Prevent hashmap size adjustment
				keyframes[keyframe_frame] = null

func seek(frame:float):
	# round up
	var qframe:int = min(ceil(frame), cached_frames.size()-1.0)
	var delta = frame-qframe
	
	var current_cached_state = cached_frames[qframe]
	var previous_cached_state = cached_frames[max(qframe-1.0,0)]

	if current_cached_state:
		for node_path in current_cached_state.nodes:
			var prev_state = previous_cached_state.nodes[node_path]
			var state = current_cached_state.nodes[node_path]
			var node = get_node_or_null(node_path)
			
			if node and node.has_method("apply_state"):
				node.apply_state(state, prev_state, delta)
	
	current_frame = frame
	elapsed_time = lerp(previous_cached_state.time, current_cached_state.time, delta)

func _physics_process(delta):
	if max_time > 0 and elapsed_time >= max_time:
		elapsed_time = max_time
		set_playing(false)

	if playing:
		_physics_frames += 1
		elapsed_time += delta
		if _physics_frames % (frame_skip+1) == 0:
			capture_frame()
			current_frame += 1.0

func _unhandled_input(event):
	var seek_speed = 0.1
	if event.is_action_pressed("ui_left", true):
		yield(get_tree(), "physics_frame")
		seek(max(current_frame-seek_speed, 0))
	
	if event.is_action_pressed("ui_right", true):
		yield(get_tree(), "physics_frame")
		seek(min(current_frame+seek_speed, cached_frames.size()))

	if event.is_action_pressed("ui_accept"):
		cut_cached_frames(current_frame)
		set_playing(true)
