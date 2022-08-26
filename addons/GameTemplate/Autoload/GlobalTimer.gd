extends Node2D

# Usage from outside:
#
# 		func _on_Button_pressed()->void:
# 			GlobalTimer.add_timeout(self, "hello_wordl", 3)
#
# 		func hello_wordl():
# 			print("Hello, World!")
#
# TODO: delete_timeout()

func add_timeout(node : Node, function : String, timeout : int)->void:
	var timer = Timer.new()
	timer = Timer.new()
	timer.set_one_shot(true)
	timer.set_wait_time(timeout)
	timer.connect("timeout", node, function)
	timer.autostart = true
	add_child(timer)
