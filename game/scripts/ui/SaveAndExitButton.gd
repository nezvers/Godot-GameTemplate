## Pause -> Main Menu: writes the run checkpoint first, so Continue resumes it.
class_name SaveAndExitButton
extends ChangeSceneButton

func pressed()->void:
	RunSession.checkpoint()
	super.pressed()
