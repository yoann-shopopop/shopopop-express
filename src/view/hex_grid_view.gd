class_name HexGridView
extends Node3D
## Renders the board: a faint background lattice, every placed tile colored by its terrain type
## (with random variants), a player-colored perimeter outline per piece, and start/pawn markers.
## Pure presentation — reads a [Board] and the [Player] list, redraws on [signal Board.changed].

var _board: Board
var _players: Array[Player] = []

var _lattice: MultiMeshInstance3D
var _tiles: MultiMeshInstance3D
var _outlines: MultiMeshInstance3D
var _markers: Node3D


func setup(board: Board, players: Array[Player]) -> void:
	_board = board
	_players = players
	_board.changed.connect(_refresh)
	_build_lattice()
	_tiles = _make_tile_instance(GameConfig.HEX_SIZE)
	_outlines = _make_outline_instance()
	_markers = Node3D.new()
	add_child(_markers)
	_refresh()


# --- Mesh/instance factories ------------------------------------------------

func _make_tile_instance(size: float) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = HexMeshFactory.create_tile(size, GameConfig.TILE_HEIGHT)
	inst.multimesh = mm
	inst.material_override = _albedo_material(false)
	add_child(inst)
	return inst


func _make_outline_instance() -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()  # unit box, scaled per-instance by the outline transforms
	inst.multimesh = mm
	inst.material_override = _albedo_material(true)
	add_child(inst)
	return inst


func _albedo_material(unshaded: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true  # opaque; per-instance colors drive albedo
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


# --- Static lattice ---------------------------------------------------------

func _build_lattice() -> void:
	_lattice = _make_tile_instance(GameConfig.HEX_SIZE * 0.94)
	_lattice.multimesh.mesh = HexMeshFactory.create_tile(GameConfig.HEX_SIZE * 0.94, 0.02)
	var cells: Array[Vector2i] = []
	var radius := GameConfig.GRID_RADIUS
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			cells.append(Vector2i(q, r))
	_lattice.multimesh.instance_count = cells.size()
	for i in cells.size():
		_lattice.multimesh.set_instance_transform(i, _flat_transform(cells[i], -0.02))
		_lattice.multimesh.set_instance_color(i, GameConfig.LATTICE_COLOR)


func _flat_transform(cell: Vector2i, y: float) -> Transform3D:
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = y
	return Transform3D(Basis.IDENTITY, pos)


# --- Dynamic redraw ---------------------------------------------------------

func _refresh() -> void:
	_refresh_tiles()
	_refresh_outlines()
	_refresh_markers()


func _refresh_tiles() -> void:
	var typed: Array = []
	for piece in _board.pieces():
		typed.append_array(piece.typed_cells)
	_tiles.multimesh.instance_count = typed.size()
	for i in typed.size():
		var entry: Dictionary = typed[i]
		var type: int = entry["type"]
		var variant := _variant_of(entry["cell"], CellType.variant_count(type))
		_tiles.multimesh.set_instance_transform(i, _flat_transform(entry["cell"], 0.0))
		_tiles.multimesh.set_instance_color(i, CellType.variant_color(type, variant))


func _refresh_outlines() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for piece in _board.pieces():
		var color := PlayerColor.to_color(piece.owner) if piece.owner >= 0 else Color.WHITE
		var edges := BlockOutline.perimeter_edge_transforms(
			piece.cells(), GameConfig.HEX_SIZE, GameConfig.OUTLINE_Y, GameConfig.OUTLINE_WIDTH)
		for t in edges:
			transforms.append(t)
			colors.append(color)
	_outlines.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		_outlines.multimesh.set_instance_transform(i, transforms[i])
		_outlines.multimesh.set_instance_color(i, colors[i])


# Stable pseudo-random texture variant for a cell, so redraws stay consistent.
func _variant_of(cell: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	var h: int = absi(cell.x * 73856093 ^ cell.y * 19349663)
	return h % count


# --- Markers (start points now, pawns at the end) ---------------------------

func _refresh_markers() -> void:
	for child in _markers.get_children():
		child.queue_free()
	for player in _players:
		var cell = _placed_start_cell(player)
		if cell != null:
			_markers.add_child(_make_marker(cell, PlayerColor.to_color(player.color), 0.06, 0.36))


## Adds standing pawns at every player's start (called once setup is finished).
func show_pawns() -> void:
	for player in _players:
		var cell = _placed_start_cell(player)
		if cell != null:
			_markers.add_child(_make_marker(cell, PlayerColor.to_color(player.color), 0.5, 0.22))


# The absolute start cell of [param player] if their start block has been placed, else null.
func _placed_start_cell(player: Player):
	if player.start_block == null:
		return null
	for piece in _board.pieces():
		if piece.block_def == player.start_block:
			return HexUtils.rotate(player.start_cell, piece.rotation) + piece.anchor
	return null


func _make_marker(cell: Vector2i, color: Color, height: float, radius: float) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = GameConfig.TILE_HEIGHT + height * 0.5 + 0.02
	inst.position = pos
	return inst
