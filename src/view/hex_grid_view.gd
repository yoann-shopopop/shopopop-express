class_name HexGridView
extends Node3D
## Renders the board with the real tile artwork: a faint lattice, one textured Sprite3D per cell
## (random variant; roads oriented via RoadTiling), a player-colored perimeter outline per piece,
## and the start-point (spawn) / pawn markers. Reads a [Board] + [Player] list, redraws on changes.
##
## Tiles lie flat on XZ; their 388px base aligns to the hexagon while taller artwork overflows north
## and overlaps the cell above. South tiles draw in front (slight +Y by world z) so the overflow
## occludes correctly.

const TEX_W := 450.0
const TEX_H := 500.0
const BASE_PX := 388.0
const PIXEL_SIZE := (2.0 * GameConfig.HEX_SIZE) / TEX_W
const OFFSET_Y_PX := (TEX_H - BASE_PX) / 2.0   # shift so the base region centers on the hex
const SORT_K := 0.01                           # south-over-north depth nudge
const FLAT := Basis(Vector3(1, 0, 0), -PI / 2.0)  # lay a sprite onto the ground, texture-up = north

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


# --- Tiles -------------------------------------------------------------------

func _refresh() -> void:
	for child in _tiles_root.get_children():
		child.queue_free()
	for piece in _board.pieces():
		var road_cells := _road_cells_of(piece)
		for tc in piece.typed_cells:
			_tiles_root.add_child(_make_tile(tc["cell"], tc["type"], road_cells))
	_refresh_outlines()
	_refresh_markers()


func _make_tile(cell: Vector2i, type: int, road_cells: Dictionary) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.pixel_size = PIXEL_SIZE
	sprite.offset = Vector2(0, OFFSET_Y_PX)
	sprite.shaded = false
	sprite.transparent = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var yaw := 0.0
	if type == CellType.Kind.ROUTE:
		var meta := RoadTiling.classify(_road_dirs(cell, road_cells))
		sprite.texture = TileTextures.road(meta["variant"])
		sprite.flip_h = meta["flip"]
		yaw = float(meta["steps"]) * PI / 3.0
	else:
		var variants := TileTextures.variants(type)
		sprite.texture = variants[_variant_of(cell, variants.size())]

	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = pos.z * SORT_K
	sprite.transform = Transform3D(Basis(Vector3.UP, yaw) * FLAT, pos)
	return sprite


# Set of a piece's road cells, for in-piece connectivity.
func _road_cells_of(piece: PlacedPiece) -> Dictionary:
	var set := {}
	for tc in piece.typed_cells:
		if tc["type"] == CellType.Kind.ROUTE:
			set[tc["cell"]] = true
	return set


# Directions (0..5) in which [param cell]'s in-piece road continues.
func _road_dirs(cell: Vector2i, road_cells: Dictionary) -> Array[int]:
	var dirs: Array[int] = []
	for d in 6:
		if road_cells.has(cell + HexUtils.DIRECTIONS[d]):
			dirs.append(d)
	return dirs


func _variant_of(cell: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	return absi(cell.x * 73856093 ^ cell.y * 19349663) % count


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
	mm.instance_count = cells.size()
	for i in cells.size():
		var pos := HexUtils.axial_to_world(cells[i], GameConfig.HEX_SIZE)
		pos.y = -0.02
		pos.y = -1.0  # well below the tiles so it never occludes them
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
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
	sprite.pixel_size = PIXEL_SIZE
	sprite.offset = Vector2(0, OFFSET_Y_PX)
	sprite.shaded = false
	sprite.transparent = true
	var pos := HexUtils.axial_to_world(cell, GameConfig.HEX_SIZE)
	pos.y = 0.3   # above all tiles so the entity stays visible
	sprite.transform = Transform3D(FLAT, pos)
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
	pos.y = 0.3
	inst.position = pos
	return inst
