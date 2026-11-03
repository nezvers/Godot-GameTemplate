## Try Again / Play Again: restarts the campaign the run belonged to (New Game or
## New Game+) instead of a fixed scene.
class_name CampaignRestartButton
extends ChangeSceneButton

@export var campaign_resource:CampaignResource

func pressed()->void:
	if campaign_resource != null:
		scene_path = campaign_resource.restart_scene()
	super.pressed()
