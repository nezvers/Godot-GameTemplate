@tool
extends Node
const ZRAnimBuilder = preload("zen_anim_builder.gd")
const ZRCanvas = preload("zen_canvas.gd")
const ZRElement = preload("zen_element.gd")
const ZRProps = preload("zen_props.gd")
const ZRSignalData = preload("zen_signal_data.gd")
const ZRSignalPlayer = preload("zen_signal_player.gd")
const ZRTimeline = preload("zen_timeline.gd")
##
## The per-canvas signal bus: the port of signal.c (named dispatch) plus
## anim_signal.c (the per-document bridge) and the signal half of anim_stage.c.
##
## THE ONLY USER OF add_user_signal IN THE PROJECT, which is the answer to
## "where do Godot's own signals belong here". The C splits named dispatch
## (signal.c) from the per-instance player (AnimSignalPlayer), and that split
## maps exactly onto Godot: the dispatch edge is Godot's Object signal table,
## already written in C++ and introspectable, while everything downstream -
## capture, evaluation, the sequence offset, the spawn anchor - stays plain
## data and method calls in ZRSignalPlayer.
##
## What going native buys, concretely: `await bus.terminal_finished`, and every
## authored Zen signal appearing in Godot's Node -> Signals dock, so a button
## can be wired to "TV-out" by dragging. That payoff only exists for signals
## living on a real Node, which is why this is a Node and the player is not.
##
## WHY THE SIGNALS ARE DECLARED IN _ready() AND NOT WRITTEN INTO THE .tscn
##
## Measured on 4.7.2: user signals do NOT survive PackedScene.pack() /
## instantiate(), while an @export'ed Array does. So the authored data is the
## exported Array and the signals are re-declared from it every time the scene
## loads. A "simplification" that drops the _ready() declaration breaks every
## signal AT RUNTIME ONLY, with the whole numeric suite still green - hence
## test_signal_pack_roundtrip.
##
## And they cannot be `signal` keywords at all: `signal TV-out` is a PARSE
## ERROR, because Zen signal names are document data ("TV-out", "ripple_old"),
## not identifiers. add_user_signal takes them verbatim.
##

## Emitted on the completion EDGE of a `terminal` signal, naming it. Declared
## (not a user signal) because it is ours, not the document's, so a caller can
## `await bus.terminal_finished`.
signal terminal_finished(signal_name: String)

## Emitted whenever any authored signal fires, naming it. The one hook that does
## not require knowing the document's signal names up front.
signal signal_fired(signal_name: String, params: Dictionary)

## The authored signals, as Dictionaries. Array of Dictionary round-trips
## through a .tscn natively - the same storage ZRElement.tracks already uses -
## so no Resource subclass is needed.
@export var signals_data: Array = []

## Hard off switch, and the ONLY export-purity guard that actually holds.
##
## The exporter sets it on every bus in the scene it is about to render. A frame
## must stay a pure function of (scene, t), and the global ZenSignals autoload
## outlives any one scene, so a stray emit from editor tooling is a genuine way
## to install an override mid-render. The exporter's canvas is in the
## `zen_canvas` group like any other (it is parented into the live tree), so
## being out of reach of the relay is NOT what protects it - this flag is.
## An inert bus refuses to fire and drives nothing.
@export var inert := false

var canvas: ZRCanvas = null
var player := ZRSignalPlayer.new()

## Name of the signal currently running, "" when idle.
var running_name := ""


func _ready() -> void:
    _ensure_ready()
    # Idle until something fires: a clock ticking inside the exporter's await
    # would re-pose the canvas and make every frame identical.
    set_process(false)


## Declaration is LAZY as well as eager, because _ready() is not guaranteed to
## have run by the time something fires.
##
## Godot defers _ready() to the frame after add_child(), so code that adds a
## scene and immediately fires a signal - every test here, and any `await`-free
## spawn - would find nothing declared. Making this idempotent and calling it
## from every entry point is what removes that ordering dependency, rather than
## sprinkling `await process_frame` through the callers.
func _ensure_ready() -> void:
    if canvas == null and get_parent() is ZRCanvas:
        canvas = get_parent()
    if _declared: return
    _declared = true
    for sd in signals_data: ZRSignalData.normalize(sd)
    _drop_legacy_tracks()
    _declare_signals()


var _declared := false


## Pre-point scenes keyed pos-param offsets at `Node:pos_offset_<i>:x|y`.
## Those offsets are now one constant per binding (ZRSignalData.normalize),
## and the pseudo-props the tracks pointed at are gone, so the tracks would
## only make the AnimationPlayer warn that it cannot resolve them.
func _drop_legacy_tracks() -> void:
    var ap := ZRAnimBuilder.find_player(canvas) if canvas != null else null
    if ap == null or not ap.has_animation_library(ZRAnimBuilder.SIG_LIB): return
    var lib := ap.get_animation_library(ZRAnimBuilder.SIG_LIB)
    for an in lib.get_animation_list():
        var a := lib.get_animation(an)
        for i in range(a.get_track_count() - 1, -1, -1):
            if String(a.track_get_path(i)).contains(":pos_offset_"): a.remove_track(i)
        var cap: Dictionary = a.get_meta(ZRTimeline.META_CAPTURE, {})
        for k in cap.keys():
            if String(k).contains(":pos_offset_"): cap.erase(k)


## One user signal per authored name, each connected to our own handler.
##
## The Callable's bound name IS the C's `void *user` pointer
## (anim_signal.c:38) - the same indirection, spelled in a way Godot can
## introspect. A name rather than an index, so the editor can add, remove and
## rename signals (refresh()) without repointing the others.
##
## The Dictionary parameter carries a DEFAULT, which is what makes both of
## Zen's emit forms legal through one signature: emit_signal with a missing
## argument is an error unless the receiver supplies one, so `fire("x")` and
## `fire("x", {"pos": p})` both reach the same handler.
func _declare_signals() -> void:
    for nm in names():
        if has_signal(nm) or has_user_signal(nm): continue
        add_user_signal(nm, [{"name": "params", "type": TYPE_DICTIONARY}])
        connect(nm, _on_fire.bind(nm))
        _user.append(nm)


## The user signals this bus declared, so refresh() can retire stale ones.
var _user: Array = []


## Re-sync the declared user signals with signals_data after the editor
## added, removed or renamed one. Normalizes new entries as well.
func refresh() -> void:
    _ensure_ready()
    for sd in signals_data: ZRSignalData.normalize(sd)
    var want := names()
    for nm in _user.duplicate():
        if want.has(nm): continue
        for c in get_signal_connection_list(nm): disconnect(nm, c["callable"])
        remove_user_signal(nm)
        _user.erase(nm)
    _declare_signals()


## Fire by name. The direct path, and what the tests call.
##
## `params` carries {"pos": Vector2} in canvas fractions. THE PRESENCE OF "pos"
## IS has_pos: a Dictionary already distinguishes absent from zero, and (0,0) is
## a legal top-left emit, so a separate bool could contradict the position -
## exactly what signal.h:33 warns about.
func fire(signal_name: String, params: Dictionary = {}) -> bool:
    _ensure_ready()
    if inert: return false
    if not has_user_signal(signal_name): return false
    emit_signal(signal_name, params)
    return true


## Fire whatever the canvas itself triggers on `kind` ("press", "release",
## "end"): the FIRST signal in list order with that trigger, so two signals
## sharing one never race (the editor flags the clash). `pos` is the pointer
## for press/release, in canvas fractions. `wrap` is the loop wrap count for
## "end" (0 = a one-shot running out, 1 = the first wrap, ...): a signal
## without `every_loop` only answers 0 or 1. False when nothing fired.
func trigger(kind: String, pos: Variant = null, wrap := 0) -> bool:
    _ensure_ready()
    for sd in signals_data:
        var sig: Dictionary = sd
        if String(sig["trigger"]) != kind: continue
        if kind == "end" and wrap > 1 and not bool(sig["every_loop"]): continue
        return fire(String(sig["name"]), {"pos": pos} if pos is Vector2 else {})
    return false


## Does any signal need pointer events (press/release triggers, a follow)?
func wants_pointer() -> bool:
    _ensure_ready()
    for sd in signals_data:
        if ZRSignalData.wants_pointer(sd): return true
    return false


## The authored signal named `signal_name`, or {}.
func find(signal_name: String) -> Dictionary:
    for sd in signals_data:
        if String((sd as Dictionary).get("name", "")) == signal_name: return sd
    return {}


func has(signal_name: String) -> bool:
    _ensure_ready()
    return has_user_signal(signal_name)


## Authored signal names, for introspection and the autoload relay.
func names() -> Array:
    var out: Array = []
    for s in signals_data:
        var nm := String((s as Dictionary).get("name", ""))
        if not nm.is_empty(): out.append(nm)
    return out


func is_running() -> bool:
    return not player.is_done()


## Still shaping the pose: running, or holding a finished TERMINAL signal's
## end pose (ZRSignalPlayer.held). What the elements ask at pose time.
func is_overriding() -> bool:
    return player.is_overriding()


## True while a terminal signal's end pose is being held.
func is_holding() -> bool:
    return player.held and not player.playing


## Hand the elements back to the timeline after a held terminal end pose, or
## let go of a follow.
func release_hold() -> void:
    if not player.held: return
    player.release()
    set_process(player.playing)
    _repose()


## Stop whatever signal is shaping the pose - running, holding or following -
## and hand the elements back to the timeline.
func release_signal() -> void:
    player.playing = false
    player.release()
    running_name = ""
    set_process(false)
    _repose()


## Start the override. Called by the user signal, so an external `emit_signal`
## on the bus works identically to fire().
func _on_fire(params: Dictionary, signal_name: String) -> void:
    _ensure_ready()
    if inert: return
    var sig := find(signal_name)
    if sig.is_empty(): return
    _start(sig, params)
    running_name = String(sig.get("name", "")) if player.playing else ""
    set_process(player.playing)

    # Restart-on-fire. Deliberately AFTER the capture: the pose the signal just
    # captured was read at the OLD doc time, so a posAnchor stays correct and
    # only the timeline is rewound (anim_stage.c:215-223).
    #
    # rewind_timeline(), NOT a fresh play(): a player ticking mid-await would
    # re-pose the canvas to its own clock during an export or a render test.
    if bool(sig.get("replay", false)) and canvas != null:
        canvas.rewind_timeline()

    signal_fired.emit(String(sig.get("name", "")), params)
    # Re-pose immediately so the override is visible on THIS frame rather than
    # only after the next _process tick. An instant (length 0) terminal signal
    # would otherwise never be seen at all.
    _repose()


## Start the player on `sig` from the pose on screen.
func _start(sig: Dictionary, params: Dictionary) -> void:
    var nm := String(sig.get("name", ""))
    # A point signal fired without a position reads the pointer once, which is
    # how a code call reacts to the mouse with no extra API.
    if String(sig.get("point", "none")) != "none" and not params.has("pos") \
            and canvas != null:
        params = params.duplicate()
        params["pos"] = canvas.pointer_pos()
    player.point_source = canvas.pointer_pos if canvas != null else Callable()
    player.start(sig, params, _seq_index(), _capture.bind(_doc_time()),
        canvas.signal_timeline(nm) if canvas != null else ZRTimeline.new(),
        func(e, p): return ZRAnimBuilder.node_name_for(canvas, e, p) \
            if canvas != null else e)


## The editor's signal key mode: show `signal_name` at `t` seconds into it,
## from the pose on screen, with none of a fire's side effects - no replay
## rewind, no running clock, no fired / terminal / chain signals.
func preview(signal_name: String, t: float) -> void:
    _ensure_ready()
    var sig := find(signal_name)
    if inert or sig.is_empty(): return
    _start(sig, {})
    running_name = ""
    set_process(false)
    if player.playing: player.clock = clampf(t, 0.0, float(sig.get("length", 0.0)))
    _repose()


## Holding a follow on the pointer after its catch-up.
func is_following() -> bool:
    return player.held and not player.playing and String(player.sig.get("point", "")) == "follow"


## Advance the signal's own clock.
##
## A signal runs on ITS OWN clock as an override: it does NOT move the document
## timeline, which keeps looping underneath while the signal blends its targets
## away from it. A pause holds the DOC clock only - a signal already in flight
## keeps running over the held pose, and can still end the instance.
func _process(delta: float) -> void:
    if Engine.is_editor_hint(): return
    advance(delta)
    _repose()


## One step of the signal clock, with the terminal edge.
##
## `was_playing` is read BEFORE the update so the completion edge is found
## entirely within this call. A cross-frame "was playing" flag would miss an
## INSTANT (length 0) signal, which is started by a fire and finishes inside its
## very first update, never observed as playing by any later frame
## (anim_stage.c:310-328).
func advance(delta: float) -> void:
    var was_playing := not player.is_done()
    if was_playing: player.update(delta)
    var just_done := was_playing and player.is_done()
    if just_done:
        var nm := running_name
        var terminal := bool(player.sig.get("terminal", false))
        running_name = ""
        # A follow keeps re-posing to the live pointer after its catch-up.
        set_process(player.is_overriding() and not terminal)
        if terminal:
            # The instance stops here, having played the authored transition
            # through, rather than being cut off. The player keeps HOLDING
            # its end pose (ZRSignalPlayer.held), so the caller's _repose()
            # draws where the signal finished, not the frozen timeline pose.
            if canvas != null: canvas.stop_timeline()
            terminal_finished.emit(nm)
        var next := ZRSignalData.chained(player.sig)
        if not next.is_empty():
            # A chain picks up where this signal left off, not from the
            # timeline: `land` starts from wherever `launch` left the rocket.
            _carry = _end_pose()
            fire(next)
            _carry = {}


## What the signal that just finished leaves on screen, for every prop it
## shaped: "elem/prop" -> value. Its end pose is posed once more to read it,
## since a finished signal no longer overrides.
func _end_pose() -> Dictionary:
    var out := {}
    if canvas == null: return out
    var was := player.held
    player.held = true
    _repose()
    var t := canvas.pose_time
    for e in canvas.elements():
        var el := e as ZRElement
        for p in ZRProps.scalars_for(el.zen_kind()):
            if el.owns(p) and el.signal_shaped(p):
                out["%s/%s" % [el.elem_name, p]] = el.prop(p, t, el.base_scalar(p))
        for p in ZRProps.colors_for(el.zen_kind()):
            if el.owns(p) and el.signal_shaped(p):
                out["%s/%s" % [el.elem_name, p]] = el.prop_color(p, t, el.base_color(p), 1.0)
    player.held = was
    return out


# ---------------------------------------------------------------------------
#  Evaluation, as asked by ZRElement._capture_signal() at pose time.
# ---------------------------------------------------------------------------

func eval(elem: String, prop: String) -> Variant:
    return player.eval(elem, prop)


func eval_color(elem: String, prop: String, alpha: float) -> Variant:
    return player.eval_color(elem, prop, alpha)


## The two ADDITIVE contributions, summed. They apply even when the signal does
## not drive the property - see rule 4 in zen_element.gd.
func offset(elem: String, prop: String) -> float:
    return player.seq_offset(elem, prop) + player.pos_anchor(elem, prop)


# ---------------------------------------------------------------------------
#  Internals
# ---------------------------------------------------------------------------

## The implicit u=0 key: this element's PLAIN pose, with no override and no loop
## blend, so a signal never compounds on a previous one (anim.c:1522-1524).
##
## Returns null for an unresolvable element, which the player stores as a
## neutral capture - matching the C's out-of-range guard (anim.c:1516-1521).
##
## A CHAINED signal is the exception: it starts from the previous link's end
## pose (_carry), so the hand-over is seamless rather than a one-frame flash of
## the timeline pose.
func _capture(elem_name: String, prop: String, t: float) -> Variant:
    var e := _find_elem(elem_name, prop)
    if e == null:
        push_warning("zen: signal targets unknown element '%s'" % elem_name)
        return null
    var key := "%s/%s" % [elem_name, prop]
    if _carry.has(key): return _carry[key]
    if ZRProps.is_color(prop):
        return e.plain_prop_color(prop, t, e.base_color(prop), 1.0)
    return e.plain_prop(prop, t, e.base_scalar(prop))


## Elements are referenced BY NAME, not by index as in the C.
##
## Godot scenes are the source of truth, where an author reordering children in
## the editor would silently repoint every index at the wrong element. The name
## matched is `elem_name`, the AUTHORED name, not Node.name, which has been
## sanitised for Godot's naming rules.
func _find_elem(nm: String, prop := "") -> ZRElement:
    if canvas == null: return null
    for e in canvas.elements():
        var el := e as ZRElement
        if el.elem_name == nm and (prop.is_empty() or el.owns(prop)):
            return el
    return null


## The time the canvas was last posed at - the pose a signal captures.
##
## Deliberately the CANVAS's record and not the player's clock: the exporter
## poses with no player running, and an editor preview poses at a scrubbed t,
## so a clock would capture the wrong pose (or t=0) in both cases.
func _doc_time() -> float:
    return canvas.pose_time if canvas != null else 0.0


## The stage sequence index for the sequence offset. 0 means "not sequenced",
## which is the only value a standalone canvas can have; a stage running
## several copies of one document sets it per copy.
func _seq_index() -> int:
    return seq


## Set by a stage when it runs several copies of one document at once.
@export var seq := 0

## The pose a chained signal starts from ("elem/prop" -> value), set only
## while advance() fires the next link.
var _carry: Dictionary = {}


## Re-pose so the override reaches the screen. Uses the LIVE doc time, which is
## the live path only - the exporter never fires a signal and never gets here.
func _repose() -> void:
    if canvas == null: return
    canvas.pose_looping(canvas.pose_time, canvas.pose_looping_flag)
