extends Control

signal playing_changed(playing)
signal get_frame(frame_state)

enum PLAYING {
	PAUSED,
	PLAYING,
	REPLAYING
}

export(PLAYING) var playing = true setget set_playing
export var max_time:float = 0

var keyframes:Dictionary = {}
var cached_frames:Array = []
var current_frame:float = 0
var elapsed_time:float = 0.0
var _physics_frames:int = 0

onready var label = $HBoxContainer/Label

class FrameState extends Reference:
	var time:float
	var nodes:Dictionary
	
	func _init(time:float):
		self.time = time
		nodes = {}

# Setters
func set_playing(value:int):
	var changed = value != playing
	playing = value
	
	if playing != PLAYING.PAUSED:
		_physics_frames = 0
	
	if changed:
		emit_signal("playing_changed", playing)

func _ready():
	pause_mode = PAUSE_MODE_PROCESS
	set_playing(playing)
	get_tree().call_group("_timeline_interface", "attach_timeline", get_path())

func capture_frame():

	var qframe:int = floor(current_frame)

	# This is a new frame
	if cached_frames.size() <= qframe:
		# Instantiate new frame container
		var current_cached_state
		current_cached_state = FrameState.new(elapsed_time)
		cached_frames.append(current_cached_state)
		emit_signal("get_frame", current_cached_state)

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
	
	if playing == PLAYING.PLAYING:
		return
	
	# round up
	var qframe:int = min(ceil(frame), cached_frames.size()-1.0)
	var delta = frame-qframe
	
	var current_cached_state = cached_frames[qframe]
	var previous_cached_state = cached_frames[max(qframe-1.0,0)]
	
	if current_cached_state:
		for node_path in current_cached_state.nodes:
			var prev_state
			var state
			var d = delta
			
			if previous_cached_state.nodes.has(node_path):
				prev_state = previous_cached_state.nodes[node_path]
			if current_cached_state.nodes.has(node_path):
				state = current_cached_state.nodes[node_path]
			
			if prev_state == null:
				prev_state = state
				d = 0
			
			var node = get_node_or_null(node_path)
			
			if node and state and node.has_method("_apply_frame"):
				node._apply_frame(state, prev_state, d)
	
	current_frame = frame
	elapsed_time = lerp(previous_cached_state.time, current_cached_state.time, delta)

func _physics_process(delta):
	label.text = str(current_frame)
	if max_time > 0 and elapsed_time >= max_time:
		elapsed_time = max_time
		set_playing(PLAYING.PAUSED)

	if playing == PLAYING.PLAYING:
		capture_frame()
		_physics_frames += 1
		elapsed_time += delta
		current_frame += 1.0


func _unhandled_input(event):
	var seek_speed = 1.0
	
	if event.is_action_pressed("ui_left", true):
		yield(get_tree(), "physics_frame")
		seek(max(current_frame-seek_speed, 0))
	
	if event.is_action_pressed("ui_right", true):
		yield(get_tree(), "physics_frame")
		seek(min(current_frame+seek_speed, cached_frames.size()))

	if event.is_action_pressed("ui_accept"):
		if playing == PLAYING.PAUSED:
			cut_cached_frames(current_frame)
			set_playing(PLAYING.PLAYING)
		else:
			set_playing(PLAYING.PAUSED)

func _on_Next_pressed():
	yield(get_tree(), "physics_frame")
	seek(min(current_frame+1.0, cached_frames.size()))


func _on_Prev_pressed():
	yield(get_tree(), "physics_frame")
	seek(max(current_frame-1.0, 0))
