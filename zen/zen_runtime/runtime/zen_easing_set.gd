@tool
extends Resource
const ZRCurve = preload("zen_curve.gd")
const ZREasing = preload("zen_easing.gd")
const ZREasingSet = preload("zen_easing_set.gd")
##
## The project's shared custom easings, by name: res://assets/easings.tres.
##
## Played scenes never need this - their curves are already baked into bezier
## keys. The scene editor does: a key it rebakes with a custom name gets its
## real curve only if the name is registered, as ZREasing falls back to linear
## for a name it does not know. Referenced by NAME because the C's custom
## easing ids were not stable across runs (anim_ease_custom.h:13-17).
##

const PATH := "res://assets/easings.tres"

@export var curves: Dictionary[String, ZRCurve] = {}


## Register every curve with ZREasing.
func register() -> void:
    for n in curves:
        ZREasing.register_custom(n, curves[n])


## Register the project's set, if there is one.
static func load_project() -> void:
    if not ResourceLoader.exists(PATH): return
    var s := load(PATH) as ZREasingSet
    if s != null: s.register()
