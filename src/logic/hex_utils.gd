class_name HexUtils
extends RefCounted
## Pure axial hexagonal math for a POINTY-TOP grid.
##
## A cell is a [Vector2i] holding axial coordinates [code](q, r)[/code].
## Conventions follow Red Blob Games (https://www.redblobgames.com/grids/hexagons/).
## This class is stateless: every method is static. No rendering, no nodes — keep it that way
## so the game logic stays unit-testable in isolation.

## The six axial neighbor directions, in clockwise order.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]


## Returns the six cells adjacent to [param cell].
static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRECTIONS:
		result.append(cell + dir)
	return result


## Returns true when [param a] and [param b] are directly adjacent.
static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return distance(a, b) == 1


## Number of steps between two cells (hex / Manhattan distance on the axial grid).
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2.0)


## Rotates [param cell] around the origin by [param steps] x 60 degrees (clockwise).
## [param steps] may be negative or greater than 6; it is normalized.
static func rotate(cell: Vector2i, steps: int) -> Vector2i:
	# Work in cube space where rotation is a simple coordinate shuffle.
	var x := cell.x
	var z := cell.y
	var y := -x - z
	var n := ((steps % 6) + 6) % 6
	for _i in range(n):
		# 60 degree clockwise rotation in cube coordinates.
		var nx := -z
		var ny := -x
		var nz := -y
		x = nx
		y = ny
		z = nz
	return Vector2i(x, z)


## Converts an axial cell to a world position on the XZ plane (y = 0).
## [param size] is the hexagon circumradius (center to a corner).
static func axial_to_world(cell: Vector2i, size: float) -> Vector3:
	var x := size * (sqrt(3.0) * cell.x + sqrt(3.0) / 2.0 * cell.y)
	var z := size * (3.0 / 2.0 * cell.y)
	return Vector3(x, 0.0, z)


## Converts a world position on the XZ plane back to the nearest axial cell.
static func world_to_axial(world: Vector3, size: float) -> Vector2i:
	var q := (sqrt(3.0) / 3.0 * world.x - 1.0 / 3.0 * world.z) / size
	var r := (2.0 / 3.0 * world.z) / size
	return _axial_round(q, r)


## Rounds fractional axial coordinates to the nearest valid cell (via cube rounding).
static func _axial_round(q: float, r: float) -> Vector2i:
	var x := q
	var z := r
	var y := -x - z
	var rx := roundf(x)
	var ry := roundf(y)
	var rz := roundf(z)
	var dx := absf(rx - x)
	var dy := absf(ry - y)
	var dz := absf(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))
