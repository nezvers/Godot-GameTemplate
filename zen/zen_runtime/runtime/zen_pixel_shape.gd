@tool
extends Resource
const ZRShape = preload("zen_shape.gd")
##
## A pixel shape: the visual asset a custom ZRShape draws.
##
## A 2-bit grid - each cell is EMPTY, FILL or OUTLINE - with NO colour of its
## own. A custom ZRShape tints fill cells with its `color` track and outline
## cells with its `outline_color` track, so both stay animatable; baking a
## colour into the asset would freeze exactly what an animation wants to move.
##
## Stored as `.tres` under res://assets/shapes/ so a scene references it as a
## real ext_resource, the inspector edits it, and every canvas using it
## redraws on `changed`.
##

const EMPTY := 0
const FILL := 1
const OUTLINE := 2

## Per-axis cap on the grid.
const GRID_MAX := 128

## Grid size in cells. Assigning it resizes, keeping the top-left region.
@export var size := Vector2i(24, 16):
    set(v):
        var nv := Vector2i(clampi(v.x, 1, GRID_MAX), clampi(v.y, 1, GRID_MAX))
        if nv == size and cells.size() == nv.x * nv.y: return
        var old := cells
        var ow := size.x
        var oh := size.y
        size = nv
        cells = PackedByteArray()
        cells.resize(nv.x * nv.y)
        for y in mini(oh, nv.y):
            for x in mini(ow, nv.x):
                var i := y * ow + x
                if i < old.size(): cells[y * nv.x + x] = old[i]
        _changed()

## Row-major cell values, size.x * size.y long.
@export var cells := PackedByteArray():
    set(v):
        cells = v
        _changed()

var _tex_fill: ImageTexture = null
var _tex_line: ImageTexture = null


func _init() -> void:
    if cells.size() != size.x * size.y:
        cells.resize(size.x * size.y)


func get_cell(x: int, y: int) -> int:
    if x < 0 or y < 0 or x >= size.x or y >= size.y: return EMPTY
    var i := y * size.x + x
    return cells[i] if i < cells.size() else EMPTY


## Set one cell. Does NOT emit `changed` - a brush stroke sets hundreds of
## cells, so the caller calls commit() once when the stroke is done.
func set_cell(x: int, y: int, v: int) -> void:
    if x < 0 or y < 0 or x >= size.x or y >= size.y: return
    cells[y * size.x + x] = v


## Publish edits made through set_cell(): drop the cached textures and tell
## every user of this resource to redraw.
func commit() -> void:
    _changed()


func count(v: int) -> int:
    return cells.count(v)


func clear() -> void:
    cells.fill(EMPTY)
    _changed()


## Every inked cell becomes `v`; empty cells stay empty (bulk ink).
func convert_ink(v: int) -> void:
    for i in cells.size():
        if cells[i] != EMPTY: cells[i] = v
    _changed()


## The boundary rule: a FILL cell with an empty
## or off-grid 4-neighbour becomes OUTLINE. Read from a copy, so a promoted
## cell does not make its neighbour an edge too and eat the whole shape.
func auto_outline() -> void:
    var src := cells.duplicate()
    var w := size.x
    var h := size.y
    for y in h:
        for x in w:
            if src[y * w + x] != FILL: continue
            var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1 \
                or src[y * w + x - 1] == EMPTY or src[y * w + x + 1] == EMPTY \
                or src[(y - 1) * w + x] == EMPTY or src[(y + 1) * w + x] == EMPTY
            if edge: cells[y * w + x] = OUTLINE
    _changed()


## The two stencils a custom ZRShape draws: white where the cell is FILL
## (resp. OUTLINE), transparent elsewhere, so a draw modulate is the tint.
## Built lazily and cached until the next change.
func fill_texture() -> ImageTexture:
    if _tex_fill == null: _tex_fill = _stencil(FILL)
    return _tex_fill


func outline_texture() -> ImageTexture:
    if _tex_line == null: _tex_line = _stencil(OUTLINE)
    return _tex_line


func _stencil(v: int) -> ImageTexture:
    var data := PackedByteArray()
    data.resize(size.x * size.y * 2)
    for i in mini(cells.size(), size.x * size.y):
        data[i * 2] = 255
        data[i * 2 + 1] = 255 if cells[i] == v else 0
    var img := Image.create_from_data(size.x, size.y, false, Image.FORMAT_LA8, data)
    return ImageTexture.create_from_image(img)


func _changed() -> void:
    _tex_fill = null
    _tex_line = null
    emit_changed()


## A shape's name is its file name: 1-23 characters, no whitespace or path /
## comment characters, and no leading `_`.
static func valid_name(n: String) -> bool:
    if n.is_empty() or n.length() > 23 or n.begins_with("_"): return false
    for ch in n:
        if ch in [" ", "\t", "#", "/", "\\", ".", ":"]: return false
    return true
