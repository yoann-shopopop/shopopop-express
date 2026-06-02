class_name TileTextures
extends RefCounted
## Loads and serves the cell textures from assets/tiles/. Roads have two oriented textures
## (straight, T); other types have a few random variants; special/spawn are single images.
## ResourceLoader caches, so repeated load() calls are cheap.

const _BASE := "res://assets/tiles/"

const _PATHS := {
	CellType.Kind.GREEN: ["green/1.png", "green/2.png", "green/3.png", "green/4.png"],
	CellType.Kind.URBAN: ["urban/1.png", "urban/2.png", "urban/3.png"],
	CellType.Kind.WATER: ["water/water.png"],
	CellType.Kind.EVENT: ["special.png"],
}


## Texture variants available for a non-road [param kind] (empty for ROUTE — use [method road]).
static func variants(kind: int) -> Array:
	var result: Array = []
	for rel in _PATHS.get(kind, []):
		result.append(load(_BASE + rel))
	return result


## Number of texture variants for [param kind] (at least 1 for known types).
static func variant_count(kind: int) -> int:
	var paths: Array = _PATHS.get(kind, [])
	return maxi(1, paths.size())


## Road texture: [param variant] 1 = straight, 2 = T branch.
static func road(variant: int) -> Texture2D:
	return load(_BASE + ("road/2.png" if variant == RoadTiling.T else "road/1.png"))


## The start-point entity texture, placed on a green cell.
static func spawn() -> Texture2D:
	return load(_BASE + "spawn.png")
