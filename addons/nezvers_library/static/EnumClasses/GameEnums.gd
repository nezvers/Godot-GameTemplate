class_name GameEnums
extends RefCounted

enum DamageType {NONE, FIRE, ICE, WATER, LIGHTNING, EARTH, STEAM, ARCANE, 
				SHADOW, CURSE, TOXIC, BLUNT, PIERCE, SLASH, COUNT}

enum GameStates {NONE, TITLE, GAMEPLAY, STORE, LEVEL_EDITOR, PAUSE, CUTSCENE,
				COMPLETED, LOST, FADE_IN, FADE_OUT, SWITCH, NEW_SCENE, COUNT}

## Bitmasking flags could be used to create animation look-up table or character state managing.
enum CharacterStates{
	GROUNDED		= 1,
	VELOCITY_RIGHT	= 1 << 1,
	VELOCITY_LEFT	= 1 << 2,
	VELOCITY_UP		= 1 << 3,
	VELOCITY_DOWN	= 1 << 4,
	INPUT_RIGHT		= 1 << 5,
	INPUT_LEFT		= 1 << 6,
	INPUT_UP		= 1 << 7,
	INPUT_DOWN		= 1 << 8,
	CROUCHING		= 1 << 9,
	MOVING			= 1 << 10,
	RUNNING			= 1 << 11,
	DASHING			= 1 << 12,
	WALL_SLIDE		= 1 << 13,
	JUMPING			= 1 << 14,
	HANGING			= 1 << 15,
	LADDER			= 1 << 16, # combine with moving
	LEDGE			= 1 << 17, # Like standing on a ledge
	TURNING			= 1 << 18,
	DYING			= 1 << 19,
}
