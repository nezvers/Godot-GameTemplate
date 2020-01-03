extends Node

signal ChangeScene
signal NewGame
signal Continue
signal Resume
signal Restart
signal Options
signal Exit
signal Refocus

#For section tracking
var Paused: bool = false
var Options:bool = false
var MainMenu:bool = false
var Controls:bool = false