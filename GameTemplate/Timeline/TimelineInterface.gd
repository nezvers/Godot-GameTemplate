extends Node

enum PLAYING {
	PAUSED,
	PLAYING,
	REPLAYING
}

signal complete()
signal playing_changed(playing)
signal get_frame()
signal apply_frame(frame, prev_frame, delta)

func _init():
	add_to_group("_timeline_interface")
	
func attach_timeline(timeline_path):
	var node = get_node(timeline_path)
	node.connect("get_frame", self, "_get_frame")
	node.connect("playing_changed", self, "_playing_changed")
	emit_signal("playing_changed", node.playing)

func done(frame):
	emit_signal("complete", frame)
	
func _get_frame(frame_state):
	emit_signal("get_frame")
	var frame = yield(self, "complete")
	frame_state.nodes[get_path()] = frame

func _apply_frame(frame, prev_frame, delta):
	emit_signal("apply_frame", frame, prev_frame, delta)

func _playing_changed(playing):
	emit_signal("playing_changed", playing)
