class_name BlockOutline
extends RefCounted
## Computes the perimeter of a block — the cell edges whose neighbor is NOT part of the same block
## — as a list of box transforms, so a colored outline can be drawn around each placed piece.

## Box transforms (in world space, at [param y]) for every perimeter edge of [param cells].
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
				continue  # shared (interior) edge — no outline here
			var to_neighbor := HexUtils.axial_to_world(HexUtils.DIRECTIONS[d], size)  # length = sqrt(3)*size
			var radial := Vector3(to_neighbor.x, 0.0, to_neighbor.z).normalized()
			var mid := center + radial * (size * sqrt(3.0) / 2.0)  # edge midpoint = apothem out
			mid.y = y
			# Box: local X along the edge (tangent), Z radial (thin), Y thin/up.
			var tangent := Vector3(-radial.z, 0.0, radial.x)
			var basis := Basis()
			basis.x = tangent * (size * 1.05)  # ~one hexagon side, slight overlap closes corners
			basis.y = Vector3.UP * width
			basis.z = radial * width
			result.append(Transform3D(basis, mid))
	return result
