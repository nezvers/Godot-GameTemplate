@tool
extends RefCounted
const ZRCurve = preload("zen_curve.gd")
const ZRCurveBake = preload("zen_curve_bake.gd")
const ZREasingSet = preload("zen_easing_set.gd")
##
## The built-in easings, backed by GODOT's own easing family, plus the custom
## multi-knot bezier curves.
##
## WHO OWNS THESE CURVES (decided 2026-10-18, user call):
## Godot's `Tween.interpolate_value` is the source of truth for every built-in
## name. It is a STATIC function - no Tween instance, no tree, no allocation -
## so it is as usable from a sampler as a hand-written formula is.
##
## This replaced an exact transcription of src/easing/easing.c. The two families
## agree bit-for-bit on linear/sine*/quad*/cubic* (measured: max |diff| 1e-7),
## which is 165 of the 170 keys in the bundled documents. They genuinely DIFFER
## on the rest, because Penner's bounce thresholds and Godot's are not the same
## curve:
##
##     bounceOut  p=0.40  raylib 0.892000  godot 0.910000
##     bounceOut  p=0.60  raylib 0.727000  godot 0.772500
##     expoIn     p=0.50  raylib 0.176777  godot 0.177180
##     circIn/backIn/elasticIn differ by up to 1.15
##
## So this IS a deliberate, visible change to how MAIN_MENU's ball bob and bar
## colour move (4 bounceOut keys). The raylib .webm is therefore NO LONGER the
## fidelity target; tests/ease_ref.txt is regenerated from Godot. That trade was
## made to put the project on Godot's vocabulary, so that a curve picked in
## Godot's own UI means here exactly what it means everywhere else in the engine.
##
## An earlier design note claimed Godot's easings "cannot express bounce/elastic"
## and ruled them out. That measured value-track `transition`, which really is
## pow(p,n)-only - the wrong door. The Tween family was always capable; only
## that one access path was not.
##
## THREE TIERS, resolved in this order by apply():
##   1. a registered custom ZRCurve (user-defined, overshoot + hold steps);
##   2. a built-in name -> Godot TRANS_*/EASE_*;
##   3. unknown -> LINEAR, never an error (AnimEaseByName semantics), so a
##      document referencing a deleted custom easing still loads.
##
## Custom curves are deliberately ZRCurve and not Godot's `Curve`: Curve clamps
## to its value range and offers no x-solve, so it cannot express overshoot plus
## hold steps, which bop_n_up needs (y reaches 1.5).
##
## Easing applies to the segment ENDING at a key (incoming). Callers must pass
## the RIGHT-hand key's ease. See ZRCurveBake.
##

## Built-in name -> [Tween.TransitionType, Tween.EaseType].
##
## Godot names a curve FAMILY (`TRANS_SINE`) plus a direction (`EASE_IN`); Zen
## names the pair as one string ("sineIn"), which is also the stable name a
## scene's ease tracks store. This table is the whole of the mapping, so the full Godot family is
## exposed - including the in/inOut directions the C never had names for, and
## circ/spring, which it had no curve for at all.
const GODOT_EASE := {
    "linear":      [Tween.TRANS_LINEAR,  Tween.EASE_IN],

    "sineIn":      [Tween.TRANS_SINE,    Tween.EASE_IN],
    "sineOut":     [Tween.TRANS_SINE,    Tween.EASE_OUT],
    "sineInOut":   [Tween.TRANS_SINE,    Tween.EASE_IN_OUT],

    "quadIn":      [Tween.TRANS_QUAD,    Tween.EASE_IN],
    "quadOut":     [Tween.TRANS_QUAD,    Tween.EASE_OUT],
    "quadInOut":   [Tween.TRANS_QUAD,    Tween.EASE_IN_OUT],

    "cubicIn":     [Tween.TRANS_CUBIC,   Tween.EASE_IN],
    "cubicOut":    [Tween.TRANS_CUBIC,   Tween.EASE_OUT],
    "cubicInOut":  [Tween.TRANS_CUBIC,   Tween.EASE_IN_OUT],

    "quartIn":     [Tween.TRANS_QUART,   Tween.EASE_IN],
    "quartOut":    [Tween.TRANS_QUART,   Tween.EASE_OUT],
    "quartInOut":  [Tween.TRANS_QUART,   Tween.EASE_IN_OUT],

    "quintIn":     [Tween.TRANS_QUINT,   Tween.EASE_IN],
    "quintOut":    [Tween.TRANS_QUINT,   Tween.EASE_OUT],
    "quintInOut":  [Tween.TRANS_QUINT,   Tween.EASE_IN_OUT],

    "expoIn":      [Tween.TRANS_EXPO,    Tween.EASE_IN],
    "expoOut":     [Tween.TRANS_EXPO,    Tween.EASE_OUT],
    "expoInOut":   [Tween.TRANS_EXPO,    Tween.EASE_IN_OUT],

    "circIn":      [Tween.TRANS_CIRC,    Tween.EASE_IN],
    "circOut":     [Tween.TRANS_CIRC,    Tween.EASE_OUT],
    "circInOut":   [Tween.TRANS_CIRC,    Tween.EASE_IN_OUT],

    "backIn":      [Tween.TRANS_BACK,    Tween.EASE_IN],
    "backOut":     [Tween.TRANS_BACK,    Tween.EASE_OUT],
    "backInOut":   [Tween.TRANS_BACK,    Tween.EASE_IN_OUT],

    "elasticIn":   [Tween.TRANS_ELASTIC, Tween.EASE_IN],
    "elasticOut":  [Tween.TRANS_ELASTIC, Tween.EASE_OUT],
    "elasticInOut":[Tween.TRANS_ELASTIC, Tween.EASE_IN_OUT],

    "bounceIn":    [Tween.TRANS_BOUNCE,  Tween.EASE_IN],
    "bounceOut":   [Tween.TRANS_BOUNCE,  Tween.EASE_OUT],
    "bounceInOut": [Tween.TRANS_BOUNCE,  Tween.EASE_IN_OUT],

    "springIn":    [Tween.TRANS_SPRING,  Tween.EASE_IN],
    "springOut":   [Tween.TRANS_SPRING,  Tween.EASE_OUT],
    "springInOut": [Tween.TRANS_SPRING,  Tween.EASE_IN_OUT],
}

# name -> ZRCurve, registered from assets/easings.tres (ZREasingSet).
# Referenced by NAME because custom easing ids are not stable across runs
# (anim_ease_custom.h:13-17).
static var _custom: Dictionary = {}


## Eased position for a 0..1 input. May leave 0..1 (back/elastic overshoot, and
## a custom curve can reach 1.5) - callers must not clamp.
static func apply(ease_name: String, p: float) -> float:
    # A custom curve wins over a built-in of the same name, so a document can
    # override a stock curve without the engine's name becoming unusable.
    if _custom.has(ease_name):
        return (_custom[ease_name] as ZRCurve).sample(p)
    var m: Variant = GODOT_EASE.get(ease_name)
    if m == null:
        return p                                # unknown -> linear, never fail
    # Static: no Tween instance is created, so this is safe to call from a
    # sampler inside _draw() at any rate.
    return Tween.interpolate_value(0.0, 1.0, p, 1.0, m[0], m[1])


## Is this a stock Godot-backed curve?
static func is_builtin(ease_name: String) -> bool:
    return GODOT_EASE.has(ease_name)


static func has(ease_name: String) -> bool:
    return is_builtin(ease_name) or _custom.has(ease_name)


## Every selectable easing, stock then custom - the list an authoring dropdown
## shows.
static func all_names() -> Array:
    var out: Array = GODOT_EASE.keys()
    out.append_array(_custom.keys())
    return out


static func register_custom(ease_name: String, curve: ZRCurve) -> void:
    _custom[ease_name] = curve


static func custom_names() -> Array:
    return _custom.keys()


static func clear_custom() -> void:
    _custom.clear()
