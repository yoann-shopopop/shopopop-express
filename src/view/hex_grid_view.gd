class_name HexGridView
extends Node3D
## Renders the board: a faint background lattice plus every placed tile.
## Reads from a [Board] and redraws on [signal Board.changed]. Pure presentation — it never
## decides what is legal, it only shows what the model holds.

## Yaw applied to each tile. The 6-sided CylinderMesh already has vertices on the Z axis and
## flat edges facing X (verified), which is pointy-top for our layout — so no extra yaw.
const TILE_YAW: float = 0.0

var _board: Board
var _palette: Dictionary = {}  # StringName id -> Color

var _lattice: MultiMeshInstance3D
var _placed: MultiMeshInstance3D


## Wires the view to its model and the id->color palette, then draws the initial state.
func setup(board: Board, palette: Dictionary) -> void:
	_board = board
	_palette = palette
	_board.changed.connect(_refresh_placed)
	_build_lattice()
	_refresh_placed()


func _tile_transform(cell: Vector2i, y: float) -> Transform3D:
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = y
	return Transform3D(Basis(Vector3.UP, TILE_YAW), pos)


func _make_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = HexMeshFactory.create_tile(GameConfig.HEX_SIZE, GameConfig.TILE_HEIGHT)
	return mm


func _make_instance() -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = _make_multimesh()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inst.material_override = mat
	add_child(inst)
	return inst


# The faint static lattice covering a disc of GRID_RADIUS cells around the origin.
func _build_lattice() -> void:
	_lattice = _make_instance()
	# A touch flatter and below the placed tiles so it reads as a guide, not a piece.
	_lattice.multimesh.mesh = HexMeshFactory.create_tile(GameConfig.HEX_SIZE * 0.94, 0.02)
	var cells: Array[Vector2i] = []
	var radius := GameConfig.GRID_RADIUS
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			cells.append(Vector2i(q, r))
	_lattice.multimesh.instance_count = cells.size()
	for i in cells.size():
		_lattice.multimesh.set_instance_transform(i, _tile_transform(cells[i], -0.02))
		_lattice.multimesh.set_instance_color(i, GameConfig.LATTICE_COLOR)


# Rebuilds the placed-tile instances from the current board state.
func _refresh_placed() -> void:
	if _placed == null:
		_placed = _make_instance()
	var cells := _board.get_cells()
	var keys := cells.keys()
	_placed.multimesh.instance_count = keys.size()
	for i in keys.size():
		var cell: Vector2i = keys[i]
		var id: StringName = cells[cell]
		_placed.multimesh.set_instance_transform(i, _tile_transform(cell, 0.0))
		_placed.multimesh.set_instance_color(i, _palette.get(id, Color.WHITE))
