class_name HexMeshFactory
extends RefCounted
## Builds the flat hexagonal-prism mesh used for every tile (placed, ghost, lattice).
## Using a 6-sided CylinderMesh keeps us asset-free; the 90-degree phase makes it pointy-top.

## A pointy-top hexagonal prism of the given circumradius and height.
static func create_tile(size: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.cap_top = true
	mesh.cap_bottom = true
	mesh.top_radius = size
	mesh.bottom_radius = size
	mesh.height = height
	return mesh
