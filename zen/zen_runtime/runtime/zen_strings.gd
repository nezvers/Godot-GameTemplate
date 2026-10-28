@tool
extends Resource
const ZRCanvas = preload("zen_canvas.gd")
const ZRText = preload("zen_text.gd")
##
## The scene's TEXT STRING POOL. Port of the AnimDoc string pool
## (anim.c:873-1010, zen_string_pool.c).
##
## The canvas owns it (ZRCanvas.strings) and every ZRText references the
## SAME instance - one [sub_resource] in the saved scene. A text element never
## holds words of its own: its `string_base`, and the keys of its stepped
## `string` track, are indices into `entries`. SHARING IS DELIBERATE: two
## elements pointing at one entry both follow an edit to it.
##
## INDICES ARE STABLE. A removed entry leaves a hole ("") rather than shifting
## its neighbours, because keys all over the scene store those indices; the
## editor's "clean up holes" (ZenStringOps.compact) is the only thing that
## renumbers, and it rewrites every reference as it does.
##
## Reference counting needs the scene's Animations, so it lives in
## ZenStringOps; this class knows nothing about keys.
##
## TEXT ARGUMENTS. An entry may hold %1..%9, filled from the canvas's
## sequenced packet (ZRCanvas.text_args) when a text resolves: "WAVE %1"
## with ["3"] shows "WAVE 3". %% is a literal %. The entry itself is never
## rewritten - the placeholder is the visible marker of a dynamic field.
##

@export var entries: PackedStringArray = PackedStringArray()


## The words at `i`, or "" for an index out of range or a hole.
func at(i: int) -> String:
    return entries[i] if i >= 0 and i < entries.size() else ""


func has_index(i: int) -> bool:
    return i >= 0 and i < entries.size()


## First non-empty entry equal to `text`, or -1. An empty `text` never
## matches: "" is what a hole looks like, so it is never shared by accident.
func find_text(text: String) -> int:
    if text.is_empty(): return -1
    return entries.find(text)


## Add `text` and return its index. An identical entry is REUSED, so typing
## the same words twice costs one slot (AnimDocAddString). Otherwise the first
## slot in `free` (holes the caller has checked nobody references) is filled,
## else the pool grows.
func add(text: String, free: Array = []) -> int:
    var found := find_text(text)
    if found >= 0: return found
    for i in free:
        if has_index(int(i)) and entries[int(i)].is_empty():
            entries[int(i)] = text
            emit_changed()
            return int(i)
    entries.append(text)
    emit_changed()
    return entries.size() - 1


## Put `text` at exactly index `i`, growing the pool with holes as needed.
func put(i: int, text: String) -> void:
    if i < 0: return
    while entries.size() <= i: entries.append("")
    entries[i] = text
    emit_changed()


func set_text(i: int, text: String) -> void:
    if not has_index(i): return
    entries[i] = text
    emit_changed()


## Drop every entry from `n` on (trailing holes).
func truncate(n: int) -> void:
    if n < 0 or n >= entries.size(): return
    entries.resize(n)
    emit_changed()


## `s` with %1..%9 replaced by args[0..8] and %% by %. A slot with no arg is
## left as written ("%2"), so a missing value shows in a preview instead of
## silently vanishing.
static func format(s: String, args: PackedStringArray) -> String:
    if s.find("%") < 0: return s
    var out := ""
    var i := 0
    while i < s.length():
        var c := s[i]
        if c == "%" and i + 1 < s.length():
            var n := s[i + 1]
            if n == "%":
                out += "%"
                i += 2
                continue
            if n >= "1" and n <= "9":
                var slot := n.unicode_at(0) - 49
                out += args[slot] if slot < args.size() else "%" + n
                i += 2
                continue
        out += c
        i += 1
    return out


## The 1-based argument slots `s` uses, ascending and without repeats.
static func arg_slots(s: String) -> PackedInt32Array:
    var used := {}
    var i := 0
    while i < s.length() - 1:
        if s[i] == "%":
            var n := s[i + 1]
            if n >= "1" and n <= "9": used[n.unicode_at(0) - 48] = true
            i += 2
            continue
        i += 1
    var out := PackedInt32Array(used.keys())
    out.sort()
    return out


## The highest argument slot any entry uses (0 for a pool without args).
func arg_count() -> int:
    var top := 0
    for e in entries:
        var slots := arg_slots(e)
        if not slots.is_empty(): top = maxi(top, slots[slots.size() - 1])
    return top
