class_name HexGridView
extends Node3D
## Renders the board with the real tile artwork: a faint lattice, one textured Sprite3D per cell
## (via [TileSprite]), a player-colored perimeter outline per piece, and the start-point (spawn) /
## pawn markers. Reads a [Board] + [Player] list, redraws on [signal Board.changed].

var _board: Board
var _players: Array[Player] = []

var _lattice: MultiMeshInstance3D
var _outlines: MultiMeshInstance3D
var _tiles_root: Node3D
var _markers: Node3D


func setup(board: Board, players: Array[Player]) -> void:
	_board = board
	_players = players
	_board.changed.connect(_refresh)
	_build_lattice()
	_outlines = _make_outline_instance()
	_tiles_root = Node3D.new()
	add_child(_tiles_root)
	_markers = Node3D.new()
	add_child(_markers)
	_refresh()


## Shows or hides the faint background lattice. Kept for the placement phase (a placing aid), hidden
## during play so the assembled board reads clearly instead of floating in a sea of empty cells.
func set_lattice_visible(value: bool) -> void:
	if _lattice != null:
		_lattice.visible = value


func _refresh() -> void:
	for child in _tiles_root.get_children():
		child.queue_free()
	for piece in _board.pieces():
		var road_cells := TileSprite.road_cells_of(piece.typed_cells)
		for i in piece.typed_cells.size():
			var tc: Dictionary = piece.typed_cells[i]
			var local: Vector2i = piece.block_def.cells[i]
			_tiles_root.add_child(TileSprite.make(tc["cell"], tc["type"], road_cells, GameConfig.HEX_SIZE, local))
	_refresh_outlines()
	_refresh_markers()


# --- Lattice & outlines ------------------------------------------------------

func _build_lattice() -> void:
	_lattice = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = HexMeshFactory.create_tile(GameConfig.HEX_SIZE * 0.94, 0.02)
	_lattice.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	_lattice.material_override = mat
	add_child(_lattice)
	var cells: Array[Vector2i] = []
	var radius := GameConfig.GRID_RADIUS
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			cells.append(Vector2i(q, r))
	# The 6-sided CylinderMesh is pointy-top; rotate it 30° so the lattice reads as FLAT-TOP and
	# tessellates with the flat-top layout.
	var flat_top := Basis(Vector3.UP, PI / 6.0)
	mm.instance_count = cells.size()
	for i in cells.size():
		var pos := HexUtils.axial_to_world(cells[i], GameConfig.HEX_SIZE)
		pos.y = -1.0  # well below the tiles so it never occludes them
		mm.set_instance_transform(i, Transform3D(flat_top, pos))
		mm.set_instance_color(i, GameConfig.LATTICE_COLOR)


func _make_outline_instance() -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	add_child(inst)
	return inst


func _refresh_outlines() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for piece in _board.pieces():
		var color := PlayerColor.to_color(piece.owner) if piece.owner >= 0 else Color.WHITE
		for t in BlockOutline.perimeter_edge_transforms(
				piece.cells(), GameConfig.HEX_SIZE, 1.0, GameConfig.OUTLINE_WIDTH):
			transforms.append(t)
			colors.append(color)
	_outlines.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		_outlines.multimesh.set_instance_transform(i, transforms[i])
		_outlines.multimesh.set_instance_color(i, colors[i])


# --- Markers (spawn entities now, pawns at the end) --------------------------

func _refresh_markers() -> void:
	for child in _markers.get_children():
		child.queue_free()
	for player in _players:
		var cell = _placed_start_cell(player)
		if cell != null:
			_markers.add_child(_make_spawn_sprite(cell))


## Adds standing pawns at every player's start (called once setup is finished).
func show_pawns() -> void:
	for player in _players:
		var cell = _placed_start_cell(player)
		if cell != null:
			_markers.add_child(_make_pawn(cell, PlayerColor.to_color(player.color)))


func _placed_start_cell(player: Player):
	if player.start_block == null:
		return null
	for piece in _board.pieces():
		if piece.block_def == player.start_block:
			return HexUtils.rotate(player.start_cell, piece.rotation) + piece.anchor
	return null


func _make_spawn_sprite(cell: Vector2i) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = TileTextures.spawn()
	sprite.pixel_size = (2.0 * GameConfig.HEX_SIZE) / TileSprite.TEX_W
	sprite.offset = Vector2(0, TileSprite.OFFSET_Y_PX)
	sprite.shaded = false
	sprite.transparent = true
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = 0.3  # above all tiles so the entity stays visible
	sprite.transform = Transform3D(TileSprite.FLAT, pos)
	return sprite


func _make_pawn(cell: Vector2i, color: Color) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.5
	mesh.radial_segments = 16
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inst.material_override = mat
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = 0.45
	inst.position = pos
	return inst
