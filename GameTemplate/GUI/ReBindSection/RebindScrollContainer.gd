extends ScrollContainer

onready var ActionList:VBoxContainer = $ActionList
onready var vScrollBar:VScrollBar = get_v_scrollbar()
onready var ScrollPath:NodePath = vScrollBar.get_path()

func _ready()->void:
	guiBrain.connect("newScrollContainerButton", self, "set_button_right_focus")
	yield(get_tree(), "idle_frame")
	

func set_button_right_focus(node:Control)->void: #Connect buttons that needs to be focused on
	node.focus_neighbour_right = ScrollPath

func move_scrollbar()->void:
	yield(get_tree(), "idle_frame") #to be sure changes have been done
	var focusNode = get_focus_owner()
	if !focusNode.is_in_group("ContainerFocus"):
		return
	var scrollBar:VScrollBar = get_v_scrollbar()
	var scrollDistance:float = scrollBar.get_rect().size.y
	var listSize:float = ActionList.get_rect().size.y
	var pos:float = focusNode.rect_global_position.y - rect_global_position.y
	var percent:float = pos / listSize
	#How to move VScrollBar?