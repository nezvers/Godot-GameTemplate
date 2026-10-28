@tool
extends RefCounted
const ZRAnimBuilder = preload("zen_anim_builder.gd")
const ZRCanvas = preload("zen_canvas.gd")
const ZREasing = preload("zen_easing.gd")
const ZRProps = preload("zen_props.gd")
const ZRSignalBus = preload("zen_signal_bus.gd")
const ZRSignalData = preload("zen_signal_data.gd")
const ZRTimeline = preload("zen_timeline.gd")
##
## One running Zen signal: the port of AnimSignalPlayer (anim.c:1495-1816).
##
## A signal is a named TRANSITION, not an animation. Firing it captures the
## pose that is on screen right now and eases each targeted property from that
## capture into the signal's authored keys over `length` seconds. That captured
## pose is the IMPLICIT KEY AT u=0, and it is the whole reason a signal reads as
## a transition rather than a jump.
##
## A RefCounted, like ZREasing: it is a value owned by the bus, with no
## business in the scene tree.
##
## Its keys are NOT in the signal Dictionary: they are tracks of the signal's
## Animation in the scene's AnimationPlayer, sampled through a ZRTimeline (see
## ZRAnimBuilder for the track paths and ZRTimeline for the capture rule).
##
## TWO THINGS THAT LOOK LIKE BUGS AND ARE NOT:
##
##   - Authored key times are NORMALIZED u in 0..1 of `length`; in the Animation
##     they sit at u * length seconds. `length <= 0` means "instant": u snaps
##     to 1 and the signal lands on its final key.
##   - eval() returns a Variant, null meaning "not driven". The C uses an
##     out-param plus a bool because EVERY float is a legal property value, so
##     no sentinel float can mean "no". Same reason here.
##

## Parallel to the C's ANIM_SIG_* caps. Not enforced - Godot arrays grow - but
## kept as documentation of the authoring limits the C assumed.
const KEYS_MAX := 8

var sig: Dictionary = {}          ## the authored signal (ZRSignalBus.signals_data entry)
var clock := 0.0
var playing := false
## True once a TERMINAL signal has run to its end: the player keeps answering
## with its final (u=1) pose instead of handing the elements back to the
## timeline. The canvas has stopped by then (ZRSignalBus.advance), so the
## end pose of e.g. pause_menu's `exit` is what stays on screen rather than
## the frozen timeline pose underneath it. Cleared by start() and release().
var held := false
var seq := 0                      ## stage sequence index, 0 = not sequenced
var params: Dictionary = {}       ## {"pos": Vector2}; presence of "pos" IS has_pos
## Where a `follow` signal reads its point every frame: Callable() -> Vector2
## in canvas fractions (ZRCanvas.pointer_pos). Unset, follow reads params.pos.
var point_source := Callable()

## The captured live pose, by target index: scalars and colours.
var _from_value: Array = []
var _from_color: Array = []
## The captured centre of each point_elems entry, by index.
var _from_center: Array = []
## The signal's Animation, sampled, and the elem/prop -> node-name resolver
## its track paths were baked with.
var _tl: ZRTimeline = null
var _node_of := Callable()


func has_pos() -> bool:
    return params.has("pos") or (_point() == "follow" and point_source.is_valid())


## The point: the live pointer for a follow, else the position it was fired at.
func pos() -> Vector2:
    if _point() == "follow" and point_source.is_valid():
        return point_source.call()
    return params.get("pos", Vector2.ZERO)


## Normalized progress. `length <= 0` is instant: land on the final key.
func u() -> float:
    var len_s := float(sig.get("length", 0.0))
    if len_s <= 0.0: return 1.0
    return clampf(clock / len_s, 0.0, 1.0)


## Fire. `capture` is a Callable(elem_name: String, prop: String) -> Variant
## returning the PLAIN timeline value (float or Color) - the caller owns element
## lookup, so this class never touches the scene tree.
##
## The capture MUST read the plain path, with no override installed: a signal
## captures the timeline pose and must never sample a previous signal's
## override, or re-firing mid-flight would compound (anim.c:1522-1524).
##
## `tl` is the signal's timeline (its Animation in the scene's AnimationPlayer).
func start(signal_data: Dictionary, p: Dictionary, seq_index: int,
           capture: Callable, tl: ZRTimeline, node_of := Callable()) -> void:
    sig = signal_data
    _node_of = node_of
    _tl = tl
    clock = 0.0
    playing = false
    held = false
    seq = seq_index
    params = p.duplicate()
    _from_value = []
    _from_color = []
    _from_center = []
    if sig.is_empty(): return

    var targets: Array = sig.get("targets", [])
    var point_elems: Array = sig.get("point_elems", []) if _point() != "none" else []
    var seq_targets: Array = sig.get("seq_targets", [])
    # A signal driving NOTHING does not start. mouse_ripple's `enter` signal
    # is exactly this (anim.c:1505-1507). A signal with only point bindings or
    # only seqtargets DOES start: it has a pose to ease from and a length to run.
    if targets.is_empty() and point_elems.is_empty() and seq_targets.is_empty():
        return

    for tg in targets:
        var prop := String(tg["prop"])
        var v: Variant = capture.call(String(tg["elem"]), prop)
        if ZRProps.is_color(prop):
            _from_value.append(0.0)
            _from_color.append(v if v is Color else Color(0, 0, 0, 0))
        else:
            _from_value.append(float(v) if v is float or v is int else 0.0)
            _from_color.append(Color(0, 0, 0, 0))

    # The centre each point binding eases (or is translated) FROM.
    for pe in point_elems:
        var c := Vector2.ZERO
        for ax in ["pos_x", "pos_y"]:
            var v: Variant = capture.call(String(pe["elem"]), ax)
            if v is float or v is int: c[0 if ax == "pos_x" else 1] = float(v)
        _from_center.append(c)

    playing = true


## Advance. The clock REACHING length ends playback, so a `length = 0` signal
## is done on its first update - which is why the terminal edge has to be
## checked in the same call that updates (anim_stage.c:310-328).
func update(dt: float) -> void:
    if not playing or sig.is_empty(): return
    clock += dt
    var len_s := float(sig.get("length", 0.0))
    if clock >= len_s:
        clock = len_s
        playing = false
        # A terminal signal holds its end pose; a follow keeps tracking.
        held = bool(sig.get("terminal", false)) or _point() == "follow"


func is_done() -> bool:
    return not playing


## Still contributing to the pose: running, or holding a terminal end pose.
func is_overriding() -> bool:
    return (playing or held) and not sig.is_empty()


## Drop a held end pose, handing the elements back to the timeline.
func release() -> void:
    held = false


## The scalar value this signal drives for (elem, prop), or null if it drives
## none. Point bindings are tried FIRST: they replace the authored value
## outright (anim.c:1683), and `ripple_old` has both a point binding and a
## plain target on the same element, where the point must win.
func eval(elem: String, prop: String) -> Variant:
    if not is_overriding(): return null

    var pv: Variant = point_eval(elem, prop)
    if pv != null: return pv

    var i := _target_index(elem, prop)
    if i < 0: return null
    # A target with no track has nothing to drive it with: NOT driven, so the
    # plain track (and the loop blend) stay in charge (anim.c:1687).
    var path := _path(elem, prop)
    if not _tl.has(path): return null
    return _tl.blend(path, _t(), float(_from_value[i]))


## The colour this signal drives, or null. `alpha` is supplied by the caller
## because colour props carry NO alpha of their own - it always rides a
## separate scalar track (anim.c:556).
func eval_color(elem: String, prop: String, alpha: float) -> Variant:
    if not is_overriding(): return null
    var i := _target_index(elem, prop)
    if i < 0: return null
    var path := _path(elem, prop)
    if not _tl.has_color(path): return null
    var c: Color = _tl.blend_color(path, _t(), _from_color[i])
    return Color(c.r, c.g, c.b, alpha)


## seq * seq_mult * env(u), added ON TOP of whatever else drives the property
## (anim.c:1747-1781). Scalar props only. No env keys means a constant full
## offset.
func seq_offset(elem: String, prop: String) -> float:
    if not is_overriding(): return 0.0
    if not bool(sig.get("uses_seq", false)): return 0.0
    var mult := float(sig.get("seq_mult", 0.0))
    if seq == 0 or mult == 0.0: return 0.0

    var matched := false
    for st in sig.get("seq_targets", []):
        if String(st["elem"]) == elem and String(st["prop"]) == prop:
            matched = true
            break
    if not matched: return 0.0

    var env := 1.0
    var seq_path := "%s:%s" % [ZRAnimBuilder.SEQ_NODE, ZRAnimBuilder.SEQ_PROP]
    if _tl.has(seq_path):
        env = _tl.scalar(seq_path, _t(), 0.0)
    return float(seq) * mult * env


## The spawn-anchor translation: a CONSTANT offset moving the element so its
## centre at fire time lands on the point (anim.c:1783-1816).
##
## This is what "born at the cursor" means - the element keeps its authored
## path and the whole path is translated, which is why anchor mode leaves
## point_eval() returning null. POS props only; size is left to the authored
## animation.
func pos_anchor(elem: String, prop: String) -> float:
    if not is_overriding(): return 0.0
    if _point() != "anchor" or not has_pos(): return 0.0
    if not ZRProps.is_pos(prop): return 0.0
    var i := _point_index(elem)
    if i < 0: return 0.0
    var d := pos() + _point_off(i) - (_from_center[i] as Vector2)
    return d.x if prop == "pos_x" else d.y


## Seek / follow: the bound centre eased from its capture to (point + off)
## over u with `point_ease`, or null when this signal does not move it. After
## `length` a follow sits on the point, which pos() keeps re-reading.
func point_eval(elem: String, prop: String) -> Variant:
    var mode := _point()
    if mode != "seek" and mode != "follow": return null
    if not has_pos() or not ZRProps.is_pos(prop): return null
    var i := _point_index(elem)
    if i < 0: return null
    var to := pos() + _point_off(i)
    var from := _from_center[i] as Vector2
    var k := ZREasing.apply(String(sig.get("point_ease", ZRSignalData.DEFAULT_POINT_EASE)), u())
    return lerpf(from.x, to.x, k) if prop == "pos_x" else lerpf(from.y, to.y, k)


# ---------------------------------------------------------------------------
#  Internals
# ---------------------------------------------------------------------------

func _target_index(elem: String, prop: String) -> int:
    var targets: Array = sig.get("targets", [])
    for i in targets.size():
        if String(targets[i]["elem"]) == elem and String(targets[i]["prop"]) == prop:
            return i
    return -1


func _point() -> String:
    return String(sig.get("point", "none"))


func _point_index(elem: String) -> int:
    var pes: Array = sig.get("point_elems", [])
    for i in mini(pes.size(), _from_center.size()):
        if String(pes[i]["elem"]) == elem: return i
    return -1


func _point_off(i: int) -> Vector2:
    var off: Variant = (sig["point_elems"][i] as Dictionary).get("off", Vector2.ZERO)
    return off if off is Vector2 else Vector2.ZERO


## Seconds into the signal's Animation: u * its length.
func _t() -> float:
    return u() * _tl.length()


func _path(elem: String, prop: String) -> String:
    var node := String(_node_of.call(elem, prop)) if _node_of.is_valid() else elem
    return "%s:%s" % [node, ZRProps.track_prop(prop)]
