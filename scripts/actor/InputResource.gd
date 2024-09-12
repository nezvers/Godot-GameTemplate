## Abstracts input from projects action names and directly represents
## players input that can be shared between systems
class_name InputResource
extends Resource

## Emitted when input for action is presssed
signal action_pressed
signal action_2_pressed
signal switch_weapon(dir:int)

## Used for movement direction
@export var axis:Vector2
## Used for shooting or interaction
@export var action:bool
## Used for shooting or interaction
@export var action_2:bool
## Used for aiming attacks
@export var aim_direction:Vector2



## Setter function for whole movement Vector2
func set_axis(value:Vector2)->void:
	axis = value

## Discrete setter for just movement X axis
func set_x_axis(value:float)->void:
	axis.x = value

## Discrete setter for just movement Y axis
func set_y_axis(value:float)->void:
	axis.y = value

## Setter function for aiming direction
func set_aim_direction(value:Vector2)->void:
	aim_direction = value

## Setter function for action input
func set_action(value:bool)->void:
	if value && !action:
		action_pressed.emit()
	action = value

## Setter function for action input
func set_action_2(value:bool)->void:
	if value && !action_2:
		action_2_pressed.emit()
	action_2 = value

func set_switch_weapon(dir:int)->void:
	switch_weapon.emit(dir)
