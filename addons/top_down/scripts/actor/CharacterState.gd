## Simple animation state machine just for characters
class_name CharacterStates
extends Node

@export var enabled:bool = true
@export var resource_node:ResourceNode
@export var animation_player:AnimationPlayer
enum State {NONE, IDLE, WALK}
@export var state:State = State.NONE

const animation_list:Array[StringName] = ["idle", "idle", "walk"]
var input_resource:InputResource

## Not using automatic setter functions because they are called before _ready during initialization
func _ready()->void:
	input_resource = resource_node.get_resource("input")
	assert(input_resource != null)
	set_enabled(enabled)
	var init_state: = state
	state = State.NONE # force to be a different value than called
	set_state(init_state)

## Toggle processing for animation state machine
func set_enabled(value:bool)->void:
	enabled = value
	set_process(enabled)
	#print("CharacterAnimator [INFO]: set_enabled = ", enabled)

## Sets state variable and plays an animation
## Receiving the same state gets ignored
func set_state(value:State)->void:
	if state == value:
		return
	state = value
	var animation:StringName = animation_list[state]
	animation_player.play(animation)
	#print("CharacterAnimator [INFO]: set_state = ", animation, " - ", owner.name)

## Decide which state should be active every game's frame
func _process(_delta:float)->void:
	if input_resource.axis.length_squared() > 0.001:
		set_state(State.WALK)
	else:
		set_state(State.IDLE)
