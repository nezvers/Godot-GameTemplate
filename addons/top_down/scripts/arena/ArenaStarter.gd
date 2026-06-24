## Triggers an arena section's fight when the player enters its area.
## Each entry drives one ArenaSection node and honors its prerequisite via
## try_start().
class_name SectionStarter
extends Node

## The section this entry starts (node in the same room scene).
@export var section:ArenaSection
@export var area:Area2D

func _ready()->void:
	assert(section != null)
	assert(area != null)
	# Free the entry only once its fight actually begins (prerequisite met),
	# so the player can re-enter before the gating section is cleared.
	section.fight_started.connect(owner.queue_free.call_deferred)
	# A cleared section (e.g. empty wave list) never needs its trigger.
	section.cleared.connect(owner.queue_free.call_deferred)
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(_body:Node2D)->void:
	# deferred is thread safe, since this is called on physics thread
	section.try_start.call_deferred()
