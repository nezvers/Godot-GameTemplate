extends VBoxContainer

onready var ActionList:VBoxContainer = find_node("ActionList") #Find node to keep it flexible
onready var Pop:Popup = find_node("Popup")
var ActionBind:PackedScene = preload("res://GUI/ReBindSection/ActionBind.tscn")
var ControlBind:PackedScene = preload("res://GUI/ReBindSection/ControlBind.tscn")
var ActionNamePath:String = "Name" #find_node()
var ActionAddPath:String = "AddAction" #find_node()
var ControlNamePath:String = "Name"
var ControlRemovePath:String = "RemoveAction"
var ActionNodes:Dictionary = {} #To know which node to add ControlBinds

func _ready()->void:
	set_action_list()
	Event.connect("Controls", self, "show_controls")
	#Localization
	Settings.connect("ReTranslate", self, "retranslate")
	retranslate()

func show_controls(value:bool)->void:
	visible = value

func set_action_list()->void:
	ActionNodes.clear() #Just in case resetting everything
	var list:Array = Settings.Actions#Names:String of actions in Array
	for Action in list:
		var ActionNode:VBoxContainer = ActionBind.instance()
		ActionList.add_child(ActionNode)
		ActionNodes[Action] = ActionNode #Save node for easier access
		
		var Name:Label = ActionNode.find_node("Name") #Name of actions
		var Add:Button = ActionNode.find_node("AddAction") #Used for adding new ControlBind
		Name.text = Action
		Add.connect("pressed", self, "add_control", [Action])
		guiBrain.emit_signal("newScrollContainerButton", ActionNode) #emit to send node to ScrollContainer
		set_control_list(Action)

func set_control_list(Action)->void:
	var list:Array = Settings.ActionControls[Action] #Dictionary of InputEvents for each action
	var index:int = 0
	for Name in range(list.size()): #Maybe just list would be OK but to be sure it goes right it's range()
		new_bind(Action, list[index])
		index += 1

func new_bind(Action, event)->void: #Adding bound InputEvent in the list
	var eventNode:HBoxContainer = ControlBind.instance()
	var Parent:VBoxContainer = ActionNodes[Action] #Action represented parent node
	Parent.add_child(eventNode)
	
	var BindName:Label = eventNode.find_node("Name")
	var Remove:Button = eventNode.find_node("RemoveAction")
	
	BindName.text = get_InputEvent_name(event)
	Remove.connect("pressed", self, "remove_control", [[Action, event, eventNode]]) #Name, event, node
	guiBrain.emit_signal("newScrollContainerButton", eventNode) #emit to send node to ScrollContainer

func get_InputEvent_name(event:InputEvent)->String:
	var text:String = ""
	if event is InputEventKey:
		text = "Keyboard: " + event.as_text()
	elif event is InputEventJoypadButton:
		text = "Gamepad: "
		if Input.is_joy_known(event.device):
			text+= str(Input.get_joy_button_string(event.button_index))
		else:
			text += "Btn. " + str(event.button_index)
	elif event is InputEventJoypadMotion:
		text = "Gamepad: "
		if Input.is_joy_known(event.device):
			text+= str(Input.get_joy_axis_string(event.axis)) + " "
		else:
			text += "Axis: " + str(event.axis) + " "
		text += str(round(event.axis_value))
	return text

func add_control(Name)->void:
	Pop.popup()
	yield(Pop, "NewControl")
	if Pop.NewEvent == null:
		return
	var event:InputEvent = Pop.NewEvent
	Settings.ActionControls[Name].push_back(event)
	InputMap.action_add_event(Name, event)
	new_bind(Name, event)

func remove_control(Bind:Array)->void:
	var Name:String = Bind[0]
	var event:InputEvent = Bind[1]
	var node:HBoxContainer = Bind[2]
	
	var index:int = Settings.ActionControls[Name].find(event)
	Settings.ActionControls[Name].remove(index)
	InputMap.action_erase_event(Name, event)
	node.queue_free()

func _on_Default_pressed():
	Settings.default_controls()
	for Action in ActionNodes:
		ActionNodes[Action].queue_free()
	set_action_list()

func _on_Back_pressed():
	Event.Controls = false

#Localization
func retranslate()->void:
	find_node("Default").text = tr("DEFAULT")
	find_node("Back").text = tr("BACK")
	find_node("Actions").text = tr("ACTIONS")
	#Action names
	var list:Array = Settings.Actions
	for Action in list:
		ActionNodes[Action].find_node("Name").text = tr(Action)
