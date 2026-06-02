extends GutTest
## Tests for HexUtils — pure axial hex math (pointy-top, cell = Vector2i(q, r)).

const ORIGIN := Vector2i(0, 0)


func test_neighbors_returns_six_unique_cells() -> void:
	var result := HexUtils.neighbors(ORIGIN)
	assert_eq(result.size(), 6, "an hexagon has 6 neighbors")
	var unique := {}
	for cell in result:
		unique[cell] = true
	assert_eq(unique.size(), 6, "all neighbors are distinct")


func test_every_neighbor_is_at_distance_one() -> void:
	for cell in HexUtils.neighbors(ORIGIN):
		assert_eq(HexUtils.distance(ORIGIN, cell), 1, "neighbor is at distance 1")


func test_distance_is_symmetric() -> void:
	var a := Vector2i(2, -1)
	var b := Vector2i(-1, 3)
	assert_eq(HexUtils.distance(a, b), HexUtils.distance(b, a))


func test_distance_along_one_axis() -> void:
	assert_eq(HexUtils.distance(ORIGIN, Vector2i(3, 0)), 3)
	assert_eq(HexUtils.distance(ORIGIN, Vector2i(2, -1)), 2)


func test_rotating_six_steps_returns_to_start() -> void:
	var cells := [Vector2i(1, 0), Vector2i(2, -1), Vector2i(-3, 1)]
	for cell in cells:
		assert_eq(HexUtils.rotate(cell, 6), cell, "6 x 60deg = identity")


func test_rotation_preserves_distance_from_origin() -> void:
	var cell := Vector2i(2, -1)
	var d := HexUtils.distance(ORIGIN, cell)
	for steps in range(1, 6):
		assert_eq(HexUtils.distance(ORIGIN, HexUtils.rotate(cell, steps)), d)


func test_rotating_a_direction_yields_another_direction() -> void:
	# Rotating a unit direction by one step must land on a neighbor of the origin.
	var rotated := HexUtils.rotate(Vector2i(1, 0), 1)
	assert_eq(HexUtils.distance(ORIGIN, rotated), 1)


func test_origin_maps_to_world_origin() -> void:
	assert_eq(HexUtils.axial_to_world(ORIGIN, 1.0), Vector3.ZERO)


func test_all_neighbors_are_equidistant() -> void:
	# Every neighbor sits sqrt(3) * size from the center (both orientations).
	for cell in HexUtils.neighbors(ORIGIN):
		assert_almost_eq(HexUtils.axial_to_world(cell, 1.0).length(), sqrt(3.0), 0.0001)


func test_flat_top_north_neighbor_is_due_north() -> void:
	# Flat-top: cell (0,-1) is directly north — x ~ 0, z < 0. (Distinguishes from pointy-top.)
	var north := HexUtils.axial_to_world(Vector2i(0, -1), 1.0)
	assert_almost_eq(north.x, 0.0, 0.0001)
	assert_lt(north.z, 0.0)


func test_line_links_two_cells_contiguously() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(3, -1)
	var path := HexUtils.line(a, b)
	assert_eq(path.front(), a, "starts at a")
	assert_eq(path.back(), b, "ends at b")
	assert_eq(path.size(), HexUtils.distance(a, b) + 1, "one cell per step")
	for i in range(path.size() - 1):
		assert_true(HexUtils.are_adjacent(path[i], path[i + 1]), "consecutive cells touch")


func test_world_round_trip() -> void:
	var size := 1.5
	var cells := [Vector2i(0, 0), Vector2i(3, -2), Vector2i(-4, 1), Vector2i(2, 2)]
	for cell in cells:
		var world := HexUtils.axial_to_world(cell, size)
		assert_eq(HexUtils.world_to_axial(world, size), cell, "round trip preserves the cell")
