class_name BlockOutline
extends RefCounted
## Computes a block's cell edges as box transforms so a colored outline can be drawn. The PERIMETER
## (edges whose neighbor is outside the block) frames each placed piece; the INTERIOR (edges shared
## by two cells of the same block) subdivides it, so each individual hexagon cell reads as outlined.

## Box transforms (world space, at [param y]) for every perimeter edge of [param cells].
## Each box is a thin segment of length ~one hexagon side, oriented along its edge.
static func perimeter_edge_transforms(cells: Array[Vector2i], size: float, y: float, width: float) -> Array[Transform3D]:
	var present := {}
	for c in cells:
		present[c] = true

	var result: Array[Transform3D] = []
	for c in cells:
		var center := HexUtils.axial_to_world(c, size)
		for d in 6:
			if present.has(c + HexUtils.DIRECTIONS[d]):
				continue  # shared (interior) edge — no perimeter outline here
			result.append(_edge_transform(center, d, size, y, width))
	return result


## Box transforms for every interior edge of [param cells] — edges shared by two cells of the same
## block — for a thinner per-cell outline. Each shared edge is emitted once (by its canonical owner).
static func interior_edge_transforms(cells: Array[Vector2i], size: float, y: float, width: float) -> Array[Transform3D]:
	var present := {}
	for c in cells:
		present[c] = true

	var result: Array[Transform3D] = []
	for c in cells:
		var center := HexUtils.axial_to_world(c, size)
		for d in 6:
			var n := c + HexUtils.DIRECTIONS[d]
			if not present.has(n):
				continue  # perimeter edge — drawn by the thicker outline
			if not _owns_shared_edge(c, n):
				continue  # the neighbour cell emits this shared edge
			result.append(_edge_transform(center, d, size, y, width))
	return result


# One edge box: local X along the edge (tangent), Z radial (thin), Y thin/up; centered on the edge
# midpoint (the apothem out from the cell center, in direction [param d]).
static func _edge_transform(center: Vector3, d: int, size: float, y: float, width: float) -> Transform3D:
	var to_neighbor := HexUtils.axial_to_world(HexUtils.DIRECTIONS[d], size)  # length = sqrt(3)*size
	var radial := Vector3(to_neighbor.x, 0.0, to_neighbor.z).normalized()
	var mid := center + radial * (size * sqrt(3.0) / 2.0)  # edge midpoint = apothem out
	mid.y = y
	var tangent := Vector3(-radial.z, 0.0, radial.x)
	var basis := Basis()
	basis.x = tangent * (size * 1.05)  # ~one hexagon side, slight overlap closes corners
	basis.y = Vector3.UP * width
	basis.z = radial * width
	return Transform3D(basis, mid)


# Canonical owner of a shared edge, so it is emitted exactly once: the lexicographically smaller cell.
static func _owns_shared_edge(c: Vector2i, n: Vector2i) -> bool:
	return c.x < n.x or (c.x == n.x and c.y < n.y)
