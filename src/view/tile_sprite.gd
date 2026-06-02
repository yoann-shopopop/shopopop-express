class_name TileSprite
extends RefCounted
## Builds a single textured cell as a flat Sprite3D: base 388px aligned to the hexagon, taller art
## overflowing north, roads oriented via RoadTiling. Shared by the board view, the ghost and the
## UI previews so they all look identical.

const TEX_W := 450.0
const TEX_H := 500.0
const BASE_PX := 388.0
const OFFSET_Y_PX := (TEX_H - BASE_PX) / 2.0      # center the base region on the hex
const SORT_K := 0.01                              # south-over-north depth nudge
const FLAT := Basis(Vector3(1, 0, 0), -PI / 2.0)  # lay flat, texture-up = north


## A textured sprite for [param cell] of [param type]. [param road_cells] is the set (Dictionary
## keyed by Vector2i) of road cells in the same piece, used to orient roads. [param variant_seed]
## is the cell's LOCAL offset within its block, so the random texture variant stays stable wherever
## the block is previewed, placed or rotated.
static func make(cell: Vector2i, type: int, road_cells: Dictionary, size: float, variant_seed: Vector2i) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.pixel_size = (2.0 * size) / TEX_W
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


static func _road_dirs(cell: Vector2i, road_cells: Dictionary) -> Array[int]:
	var dirs: Array[int] = []
	for d in 6:
		if road_cells.has(cell + HexUtils.DIRECTIONS[d]):
			dirs.append(d)
	return dirs


static func _variant_of(cell: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	return absi(cell.x * 73856093 ^ cell.y * 19349663) % count
