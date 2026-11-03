## Shows the title's New Game+ button only once it is unlocked.
extends Node

@export var campaign_resource:CampaignResource
## The menu button (PanelContainer) to show or hide.
@export var entry:Control

func _ready()->void:
	assert(campaign_resource != null)
	campaign_resource.load_resource()
	campaign_resource.updated.connect(_refresh)
	_refresh()

func _refresh()->void:
	entry.visible = campaign_resource.ng_plus_unlocked
