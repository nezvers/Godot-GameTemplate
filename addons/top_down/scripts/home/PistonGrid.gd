## The home base memory: a size x size array of pistons addressed like a RAM chip.
## Row levers (an extra column on the right, +x) and column levers (an extra row
## at the bottom, +y) select lanes. The gate lever picks how a row select and a
## column select combine into a cell select (AND: only crossings, OR, XOR, ...);
## the DataLever picks raise or lower and the WriteButton puts that value into
## every selected cell at once. A wet piston shorts out on write and keeps its
## old value, so the water gun masks single bits.
## Cell (0, 0) and lever 1 sit at the bottom-right corner where the lever row and
## lever column meet (the control room); indices grow away from it.
class_name PistonGrid
extends Node2D

## Emitted when a write has run through every selected cell (WriteResult -> count)
signal written(results:Dictionary)
## Lanes, data value or piston states changed (HomeBase saves on it)
signal changed
## A write begins (co-op: the host tells its guests, NetHome)
signal write_started

enum Axis {ROW, COL}

## How a row select and a column select combine into a cell select
enum Gate {AND, OR, XOR, NAND, NOR, XNOR}

const PISTON_GRID_REFERENCE:ReferenceNodeResource = preload("res://addons/top_down/resources/ReferenceNodeResources/piston_grid_reference.tres")

@export var size:int = 30
## Floor cell of piston (0, 0), the corner piston next to both lever lanes;
## rows grow along -y, columns along -x
@export var origin_cell:Vector2i
@export var floor_layer:TileMapLayer
@export var piston_scene:PackedScene
@export var lever_scene:PackedScene
## Saved state, optional (tests run without it)
@export var home_base_resource:HomeBaseResource
## Seconds between diagonals of a write, so it ripples across the grid
@export var ripple_delay:float = 0.03

var pistons:Array[Piston]
var row_levers:Array[GridLever]
var col_levers:Array[GridLever]
var row_select:PackedByteArray
var col_select:PackedByteArray
## Value Write puts into the selected cells: true raises
var data_value:bool = true
var gate:Gate = Gate.AND
## Cells the current selects and gate pick, row-major
var _cell_select:PackedByteArray
var _selected_count:int
## Set while a write ripples through the grid
var writing:bool

func _ready()->void:
	y_sort_enabled = true
	row_select.resize(size)
	col_select.resize(size)
	_cell_select.resize(size * size)
	for _r:int in size:
		for _c:int in size:
			var _piston:Piston = piston_scene.instantiate()
			_piston.name = "Piston_%d_%d" % [_c, _r]
			_piston.cell = Vector2i(_c, _r)
			_piston.position = _cell_position(Vector2i(_c, _r))
			add_child(_piston)
			pistons.append(_piston)
	for _i:int in size:
		row_levers.append(_add_lever(Axis.ROW, _i, Vector2i(-1, _i)))
		col_levers.append(_add_lever(Axis.COL, _i, Vector2i(_i, -1)))
	PISTON_GRID_REFERENCE.set_reference(self)
	# after TileNavigationSetter made the AStar grid pistons mark as solid
	_restore.call_deferred()

func _add_lever(axis:Axis, index:int, cell:Vector2i)->GridLever:
	var _lever:GridLever = lever_scene.instantiate()
	# a fixed name: co-op guests press it by node path (NetHome)
	_lever.name = "%sLever%d" % ["Row" if axis == Axis.ROW else "Col", index + 1]
	_lever.grid = self
	_lever.axis = axis
	_lever.index = index
	_lever.position = _cell_position(cell)
	add_child(_lever)
	return _lever

## Grid cell -> floor cell; -1 is the lever lane past the corner
func _map_cell(cell:Vector2i)->Vector2i:
	return origin_cell - cell

func _cell_position(cell:Vector2i)->Vector2:
	return to_local(floor_layer.to_global(floor_layer.map_to_local(_map_cell(cell))))

## Grid cell whose visible floor tile is under a global position, (-1, -1) off the grid
func cell_at(global_pos:Vector2)->Vector2i:
	var _cell:Vector2i = origin_cell - floor_layer.local_to_map(floor_layer.to_local(global_pos))
	if _cell.x < 0 || _cell.y < 0 || _cell.x >= size || _cell.y >= size:
		return Vector2i(-1, -1)
	return _cell

func piston(cell:Vector2i)->Piston:
	if cell.x < 0 || cell.y < 0 || cell.x >= size || cell.y >= size:
		return null
	return pistons[cell.y * size + cell.x]

## Soaks the single piston whose floor cell a shot landed on, raised or not, so
## a lowered piston hidden behind a raised one can still be aimed at.
## Returns false off the grid (the shot leaves a puddle instead).
func wet_at(global_pos:Vector2)->bool:
	var _target:Piston = piston(cell_at(global_pos))
	if _target == null:
		return false
	_target.wet()
	return true

func is_selected(axis:Axis, index:int)->bool:
	return (row_select if axis == Axis.ROW else col_select)[index] == 1

func set_selected(axis:Axis, index:int, value:bool)->void:
	if axis == Axis.ROW:
		row_select[index] = int(value)
		row_levers[index].set_on(value)
	else:
		col_select[index] = int(value)
		col_levers[index].set_on(value)
	_update_preview()
	changed.emit()

func toggle(axis:Axis, index:int)->void:
	set_selected(axis, index, !is_selected(axis, index))

## Reset button: every lane lever off
func clear_selection()->void:
	row_select.fill(0)
	col_select.fill(0)
	for _i:int in size:
		row_levers[_i].set_on(false)
		col_levers[_i].set_on(false)
	_update_preview()
	changed.emit()

func set_data_value(value:bool)->void:
	data_value = value
	changed.emit()

func set_gate(value:Gate)->void:
	gate = value
	_update_preview()
	changed.emit()

## Gate lever: AND -> OR -> XOR -> NAND -> NOR -> XNOR -> AND
func next_gate()->void:
	set_gate(((gate + 1) % Gate.size()) as Gate)

static func gate_name(value:Gate)->String:
	return Gate.keys()[value]

static func combine(value:Gate, row:bool, col:bool)->bool:
	match value:
		Gate.AND: return row && col
		Gate.OR: return row || col
		Gate.XOR: return row != col
		Gate.NAND: return !(row && col)
		Gate.NOR: return !(row || col)
		_: return row == col

func is_cell_selected(cell:Vector2i)->bool:
	return _cell_select[cell.y * size + cell.x] == 1

func selected_cells()->Array[Vector2i]:
	var _cells:Array[Vector2i] = []
	for _i:int in _cell_select.size():
		if _cell_select[_i] == 1:
			_cells.append(Vector2i(_i % size, _i / size))
	return _cells

## Number of cells a write would touch
func selected_count()->int:
	return _selected_count

## Writes data_value into every selected cell, rippling out from the corner cell (0, 0).
func write()->void:
	if writing:
		return
	writing = true
	write_started.emit()
	var _results:Dictionary = {}
	var _by_diagonal:Dictionary = {}
	for _cell:Vector2i in selected_cells():
		var _d:int = _cell.x + _cell.y
		if !_by_diagonal.has(_d):
			_by_diagonal[_d] = []
		_by_diagonal[_d].append(_cell)
	var _diagonals:Array = _by_diagonal.keys()
	_diagonals.sort()
	var _last:int = _diagonals[0] if !_diagonals.is_empty() else 0
	for _d:int in _diagonals:
		if ripple_delay > 0.0 && _d > _last:
			await get_tree().create_timer(ripple_delay * (_d - _last), false).timeout
		_last = _d
		for _cell:Vector2i in _by_diagonal[_d]:
			var _result:Piston.WriteResult = piston(_cell).try_write(data_value)
			_results[_result] = _results.get(_result, 0) + 1
	writing = false
	changed.emit()
	written.emit(_results)

func _update_preview()->void:
	_selected_count = 0
	for _r:int in size:
		for _c:int in size:
			var _on:bool = combine(gate, row_select[_r] == 1, col_select[_c] == 1)
			_cell_select[_r * size + _c] = int(_on)
			_selected_count += int(_on)
			pistons[_r * size + _c].set_selected(_on)

## Raised pistons as row-major bytes
func piston_bytes()->PackedByteArray:
	var _bytes:PackedByteArray = PackedByteArray()
	_bytes.resize(pistons.size())
	for _i:int in pistons.size():
		_bytes[_i] = int(pistons[_i].is_raised())
	return _bytes

## Co-op guest: the host's grid as it is (NetHome). With `then_write` the
## host's write follows, rippling here as it does there; its outcome arrives
## with the next state.
func apply_net_state(state:Dictionary, then_write:bool)->void:
	if int(state.get("size", -1)) != size:
		return
	var _pistons:PackedByteArray = state.get("pistons", PackedByteArray())
	var _rows:PackedByteArray = state.get("rows", PackedByteArray())
	var _cols:PackedByteArray = state.get("cols", PackedByteArray())
	if _pistons.size() != pistons.size() || _rows.size() != size || _cols.size() != size:
		return
	if writing:
		# our ripple is still running: the host's outcome lands after it
		written.connect(func (_results:Dictionary)->void: apply_net_state(state, then_write), CONNECT_ONE_SHOT)
		return
	for _i:int in pistons.size():
		var _raised:bool = _pistons[_i] == 1
		if pistons[_i].is_raised() != _raised:
			pistons[_i].set_raised(_raised, then_write)
	for _i:int in size:
		row_select[_i] = _rows[_i]
		row_levers[_i].set_on(_rows[_i] == 1)
		col_select[_i] = _cols[_i]
		col_levers[_i].set_on(_cols[_i] == 1)
	data_value = bool(state.get("data", true))
	gate = clampi(int(state.get("gate", 0)), 0, Gate.size() - 1) as Gate
	_update_preview()
	changed.emit()
	if then_write:
		write()

func save_to(resource:HomeBaseResource)->void:
	resource.grid_size = size
	resource.pistons = piston_bytes()
	resource.row_select = row_select
	resource.col_select = col_select
	resource.data_value = data_value
	resource.gate = gate

func _restore()->void:
	if home_base_resource == null || home_base_resource.grid_size != size:
		return
	for _i:int in mini(pistons.size(), home_base_resource.pistons.size()):
		if home_base_resource.pistons[_i] == 1:
			pistons[_i].set_raised(true, true)
	for _i:int in size:
		if _i < home_base_resource.row_select.size():
			row_select[_i] = home_base_resource.row_select[_i]
			row_levers[_i].set_on(row_select[_i] == 1)
		if _i < home_base_resource.col_select.size():
			col_select[_i] = home_base_resource.col_select[_i]
			col_levers[_i].set_on(col_select[_i] == 1)
	data_value = home_base_resource.data_value
	gate = clampi(home_base_resource.gate, 0, Gate.size() - 1) as Gate
	_update_preview()
