## Shows a menu's Upgrades button once a boss crystal has ever been picked up
## (spent ones count, so spending them at the workbench never hides it).
extends Node

@export var boss_crystal_resource:ScoreResource
@export var meta_upgrade_resource:MetaUpgradeResource
## The menu button (PanelContainer) to show or hide.
@export var entry:Control

static func is_unlocked(crystals:ScoreResource, meta:MetaUpgradeResource)->bool:
	return crystals.collected_total > 0 || crystals.value > 0 || !meta.owned.is_empty()

func _ready()->void:
	assert(boss_crystal_resource != null)
	assert(meta_upgrade_resource != null)
	boss_crystal_resource.load_resource()
	meta_upgrade_resource.load_resource()
	boss_crystal_resource.updated.connect(_refresh)
	meta_upgrade_resource.updated.connect(_refresh)
	_refresh()

func _refresh()->void:
	entry.visible = is_unlocked(boss_crystal_resource, meta_upgrade_resource)
