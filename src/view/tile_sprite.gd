class_name TileSprite
extends RefCounted
## Builds a single textured cell as a flat Sprite3D. Two art sets coexist: the new flat-top hex art
## (water/green/urban/event, ≈248×215, no overflow) and the ORIGINAL road art (450×500, drawn for the
## RoadTiling convention so markings line up), each with its own geometry. Shared by the board view,
## the ghost and the UI previews so they all look identical.

const TEX_W := 248.0                              # new art = flat-top hex bounding box (≈248×215)
const TEX_H := 215.0
const BASE_PX := 215.0                            # the art fills the hex; no northward overflow
const OFFSET_Y_PX := (TEX_H - BASE_PX) / 2.0      # 0 — kept as a formula for clarity
# Roads keep the original art + geometry (a 388px hex base centered in a 500px canvas, art overflows
# north) so the markings orient correctly via RoadTiling.
const ROAD_TEX_W := 450.0
const ROAD_OFFSET_Y_PX := (500.0 - 388.0) / 2.0   # 56
const SORT_K := 0.01                              # south-over-north depth nudge
const FLAT := Basis(Vector3(1, 0, 0), -PI / 2.0)  # lay flat, texture-up = north


## A textured sprite for [param cell] of [param type]. [param road_cells] is the set (Dictionary
## keyed by Vector2i) of road cells in the same piece, used to orient roads. [param variant_seed]
## is the cell's LOCAL offset within its block, so the random texture variant stays stable wherever
## the block is previewed, placed or rotated.
static func make(cell: Vector2i, type: int, road_cells: Dictionary, size: float, variant_seed: Vector2i, piece_cells: Dictionary = {}, is_drive: bool = false) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.shaded = false
	sprite.transparent = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var yaw := 0.0
	if type == CellType.Kind.ROUTE:
		# Roads use the original art + geometry (markings drawn for the RoadTiling convention).
		sprite.pixel_size = (2.0 * size) / ROAD_TEX_W
		sprite.offset = Vector2(0, ROAD_OFFSET_Y_PX)
		var dirs := _road_dirs(cell, road_cells)
		if dirs.is_empty():
			# A lone road cell = a bridge's central road (flanked only by its own water ends). Use the
			# diagonal-marking texture, rotated to the span axis. The span is a hex axis, so 60° steps
			# keep the hexagon flat-top aligned (no 90° turn that would rotate the hexagon itself).
			var span := _piece_dirs(cell, piece_cells)
			sprite.texture = TileTextures.road_bridge()
			if span.size() > 0:
				yaw = float(span[0] % 3) * PI / 3.0
		else:
			var meta := RoadTiling.classify(dirs)
			sprite.texture = TileTextures.road(meta["variant"])
			sprite.flip_h = meta["flip"]
			yaw = float(meta["steps"]) * PI / 3.0
	else:
		# New flat-top hex art (no overflow).
		sprite.pixel_size = (2.0 * size) / TEX_W
		sprite.offset = Vector2(0, OFFSET_Y_PX)
		if type == CellType.Kind.URBAN and is_drive:
			# The pickup point's urban cell shows the DRIVE storefront art (the enseigne jeton on top).
			var drives := TileTextures.drive_variants()
			sprite.texture = drives[_variant_of(variant_seed, drives.size())]
		else:
			var variants := TileTextures.variants(type)
			sprite.texture = variants[_variant_of(variant_seed, variants.size())]

	var pos := HexUtils.axial_to_world(cell, size)
	pos.y = pos.z * SORT_K
	sprite.transform = Transform3D(Basis(Vector3.UP, yaw) * FLAT, pos)
	return sprite


## Road cells (set) of a piece from its typed cells, for connectivity. Special/event cells count
## as roads (they are roads with a unique texture).
static func road_cells_of(typed_cells: Array) -> Dictionary:
	var set := {}
	for tc in typed_cells:
		if CellType.is_road(tc["type"]):
			set[tc["cell"]] = true
	return set


## All cells (set) of a piece — used to orient an isolated road cell (e.g. a bridge's central road,
## flanked only by its own water ends) along the piece instead of an arbitrary default axis.
static func cells_of(typed_cells: Array) -> Dictionary:
	var set := {}
	for tc in typed_cells:
		set[tc["cell"]] = true
	return set


# Directions in which the road continues: toward adjacent road cells of the same piece.
static func _road_dirs(cell: Vector2i, road_cells: Dictionary) -> Array[int]:
	var dirs: Array[int] = []
	for d in 6:
		if road_cells.has(cell + HexUtils.DIRECTIONS[d]):
			dirs.append(d)
	return dirs


# Directions toward the cell's same-piece neighbours — the bridge's span axis for its lone road cell.
static func _piece_dirs(cell: Vector2i, piece_cells: Dictionary) -> Array[int]:
	var dirs: Array[int] = []
	for d in 6:
		if piece_cells.has(cell + HexUtils.DIRECTIONS[d]):
			dirs.append(d)
	return dirs


static func _variant_of(cell: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	return absi(cell.x * 73856093 ^ cell.y * 19349663) % count
