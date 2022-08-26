extends Node2D

func add_timeout(node : Node, function : String, timeout : int)->void:
	var timer = Timer.new()
	timer = Timer.new()
	timer.set_one_shot(true)
	timer.set_wait_time(timeout)
	timer.connect("timeout", node, function)
	timer.autostart = true
	add_child(timer)
