class_name HexGridView
extends Node3D
## Renders the board with the real tile artwork: one textured Sprite3D per cell (via [TileSprite]),
## a player-colored perimeter outline per piece, and the start-point (spawn) / pawn markers. Reads a
## [Board] + [Player] list, redraws on [signal Board.changed]. No empty-cell lattice is drawn — pieces
## float on the backdrop ("in the void").

var _board: Board
var _players: Array[Player] = []

var _outlines: MultiMeshInstance3D
var _tiles_root: Node3D
var _markers: Node3D
var _grounding: Node3D       # light pool + soft contact shadow under the whole assembled board
var _shadow_tex: Texture2D
var _glow_tex: Texture2D
var _drive_cells: Dictionary = {}  # cells (set) that host a delivery's DRIVE storefront art
var _spent_event_cells: Dictionary = {}  # event cells (set) consumed this round (inert texture)


func setup(board: Board, players: Array[Player]) -> void:
	_board = board
	_players = players
	_board.changed.connect(_refresh)
	_grounding = Node3D.new()
	add_child(_grounding)
	_outlines = _make_outline_instance()
	_tiles_root = Node3D.new()
	add_child(_tiles_root)
	_markers = Node3D.new()
	add_child(_markers)
	_refresh()


## Sets which cells host a delivery's DRIVE storefront art (the real, possibly cross-tile drives), then
## redraws. Called by [Main] once [GameRoot] has built the deliveries.
func set_drive_cells(cells: Array) -> void:
	_drive_cells.clear()
	for cell in cells:
		_drive_cells[cell] = true
	if _tiles_root != null:
		_refresh()


## Sets which event (rainbow) cells are consumed this round (drawn inert), then redraws. Called by
## [Main] on [GamePhase]'s event_cell_spent / event_cells_rearmed signals.
func set_spent_event_cells(cells: Array) -> void:
	_spent_event_cells.clear()
	for cell in cells:
		_spent_event_cells[cell] = true
	if _tiles_root != null:
		_refresh()


func _refresh() -> void:
	_refresh_grounding()
	for child in _tiles_root.get_children():
		child.queue_free()
	for piece in _board.pieces():
		var road_cells := TileSprite.road_cells_of(piece.typed_cells)
		var piece_cells := TileSprite.cells_of(piece.typed_cells)
		for i in piece.typed_cells.size():
			var tc: Dictionary = piece.typed_cells[i]
			var local: Vector2i = piece.block_def.cells[i]
			var is_drive: bool = _drive_cells.has(tc["cell"])  # storefront art on the real delivery drives
			var sprite := TileSprite.make(tc["cell"], tc["type"], road_cells, GameConfig.HEX_SIZE, local, piece_cells, is_drive)
			if tc["type"] == CellType.Kind.EVENT and _spent_event_cells.has(tc["cell"]):
				sprite.texture = TileTextures.event_spent()  # consumed this round: drawn inert
			_tiles_root.add_child(sprite)
	_refresh_outlines()
	_refresh_markers()


# --- Grounding (soft contact shadow under the board) -------------------------

# Grounds the assembled board so it reads as a real board on a table, not flat stickers in the void:
# a warm light pool underneath it (the board sits in a spotlight) plus a soft contact shadow whose
# falloff lands just beyond the perimeter. Both follow the footprint and sit behind the tiles.
func _refresh_grounding() -> void:
	for child in _grounding.get_children():
		child.queue_free()
	var cells := _board.occupied_cells()
	if cells.is_empty():
		return
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for c in cells:
		var w := HexUtils.axial_to_world(c, GameConfig.HEX_SIZE)
		min_x = minf(min_x, w.x); max_x = maxf(max_x, w.x)
		min_z = minf(min_z, w.z); max_z = maxf(max_z, w.z)
	var span := maxf(max_x - min_x, max_z - min_z) + GameConfig.HEX_SIZE * 2.0
	var cx := (min_x + max_x) * 0.5
	var cz := (min_z + max_z) * 0.5
	# Light pool: large, soft, behind everything — focuses the eye on the board.
	_grounding.add_child(_radial_sprite(_glow_texture(), span * 2.4, -0.7, Vector3(cx, 0.0, cz)))
	# Contact shadow: tighter, nudged toward the light's far side, just above the pool.
	_grounding.add_child(_radial_sprite(_shadow_texture(), span * 1.6, -0.4, Vector3(cx + 0.5, 0.0, cz + 0.5)))


# A flat radial sprite of [param texture] spanning [param world_size], at height [param y], centered on
# [param center] (its y is overridden by [param y]).
func _radial_sprite(texture: Texture2D, world_size: float, y: float, center: Vector3) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.shaded = false
	sprite.transparent = true
	sprite.texture = texture
	sprite.pixel_size = world_size / 256.0
	sprite.rotation_degrees = Vector3(-90, 0, 0)  # lay flat on the table
	sprite.position = Vector3(center.x, y, center.z)
	return sprite


# A 256² radial alpha gradient: dark and semi-opaque at the center, fading to transparent at the rim.
func _shadow_texture() -> Texture2D:
	if _shadow_tex == null:
		_shadow_tex = _radial_texture(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.36), Color(0, 0, 0, 0.0))
	return _shadow_tex


# A warm, very soft light pool (lightens the cool backdrop under the board).
func _glow_texture() -> Texture2D:
	if _glow_tex == null:
		_glow_tex = _radial_texture(Color(1.0, 0.95, 0.84, 0.20), Color(1.0, 0.95, 0.84, 0.07), Color(1.0, 0.95, 0.84, 0.0))
	return _glow_tex


func _radial_texture(center: Color, mid: Color, edge: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, center)
	gradient.set_color(1, edge)
	gradient.add_point(0.62, mid)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


# --- Outlines ----------------------------------------------------------------

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
		# Per-cell outline: interior edges, half the perimeter width, same color.
		for t in BlockOutline.interior_edge_transforms(
				piece.cells(), GameConfig.HEX_SIZE, 1.0, GameConfig.OUTLINE_WIDTH * 0.5):
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
	# The spawn marker keeps its own art size (independent of the tile TEX_W, which changed with the
	# new hex art): scale it to ~one hex wide from its own texture width.
	sprite.pixel_size = (2.0 * GameConfig.HEX_SIZE) / maxf(float(sprite.texture.get_width()), 1.0)
	sprite.offset = Vector2(0, 0)
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
