class_name CellType
extends RefCounted
## The terrain types a board cell can have. Pure data/config — no logic.
##
## Gameplay meaning (movement cost, what a cell can host) lives elsewhere; here we only define the
## set of types and their presentation defaults (placeholder colors + how many random texture
## variants each type gets for visual variety). Real textures will replace the colors later.

enum Kind {
	ROUTE,  ## Drivable/cyclable road. Roads are the only movement surface (save events).
	GREEN,  ## Green space — hosts recipients (destinataires) and player start points.
	URBAN,  ## Grey urbanized zone — hosts pickup points (points de retrait).
	WATER,  ## Water — impassable; the bridge's end cells are water.
	EVENT,  ## Special cell: a ROAD with a unique texture that triggers an event when crossed.
}


## True for cells that are part of the road network (a plain road, or a special/event road cell).
static func is_road(kind: int) -> bool:
	return kind == Kind.ROUTE or kind == Kind.EVENT

# Placeholder albedo per type, used until real per-cell textures exist.
const _COLORS := {
	Kind.ROUTE: Color("3a3f4b"),
	Kind.GREEN: Color("6aa84f"),
	Kind.URBAN: Color("9aa0a6"),
	Kind.WATER: Color("5b9bd5"),
	Kind.EVENT: Color("c97fd6"),
}

# How many random texture variants each type cycles through (for "joli" visual variety).
const _VARIANTS := {
	Kind.ROUTE: 1,
	Kind.GREEN: 3,
	Kind.URBAN: 3,
	Kind.WATER: 3,
	Kind.EVENT: 1,
}


## Placeholder color for [param kind].
static func color(kind: int) -> Color:
	return _COLORS.get(kind, Color.MAGENTA)


## A slightly shaded variant color, so repeated cells of a type aren't perfectly flat.
## [param variant] in [0, variant_count(kind)).
static func variant_color(kind: int, variant: int) -> Color:
	var base := color(kind)
	var count := variant_count(kind)
	if count <= 1:
		return base
	# Spread brightness by +/- ~12% across the variants.
	var t := float(variant) / float(count - 1)  # 0..1
	var factor := lerpf(0.88, 1.12, t)
	return Color(base.r * factor, base.g * factor, base.b * factor, base.a)


## Number of random texture variants for [param kind] (at least 1).
static func variant_count(kind: int) -> int:
	return _VARIANTS.get(kind, 1)
