extends GutTest
## Tests for the BFS reachability helpers added to RoadNetwork (distances_from / is_reachable), used
## by the delivery reachability guard and trajectory steering. Pure logic over a walkable set.


# A straight corridor of road cells (0,0)..(3,0).
func _corridor() -> Dictionary:
	var walkable := {}
	for x in range(4):
		walkable[Vector2i(x, 0)] = true
	return walkable


func test_distances_from_marks_start_at_zero() -> void:
	var d := RoadNetwork.distances_from(_corridor(), Vector2i(0, 0))
	assert_eq(d[Vector2i(0, 0)], 0)


func test_distances_grow_along_the_corridor() -> void:
	var d := RoadNetwork.distances_from(_corridor(), Vector2i(0, 0))
	assert_eq(d[Vector2i(1, 0)], 1)
	assert_eq(d[Vector2i(3, 0)], 3)


func test_unwalkable_cells_are_absent() -> void:
	var d := RoadNetwork.distances_from(_corridor(), Vector2i(0, 0))
	assert_false(d.has(Vector2i(0, 5)), "a cell off the corridor is not reached")


func test_is_reachable_within_the_corridor() -> void:
	assert_true(RoadNetwork.is_reachable(_corridor(), Vector2i(0, 0), Vector2i(3, 0)))


func test_is_not_reachable_across_a_gap() -> void:
	var walkable := {Vector2i(0, 0): true, Vector2i(2, 0): true}  # (1,0) missing: a gap
	assert_false(RoadNetwork.is_reachable(walkable, Vector2i(0, 0), Vector2i(2, 0)))


func test_extra_cells_bridge_an_off_road_destination() -> void:
	# A drive cell (1,1) sits off the corridor; with no extra it is unreachable, as extra it is.
	var off := Vector2i(1, 1)  # neighbour of (1,0) and (0,1)
	assert_false(RoadNetwork.is_reachable(_corridor(), Vector2i(0, 0), off))
	assert_true(RoadNetwork.is_reachable(_corridor(), Vector2i(0, 0), off, {off: true}))


func test_start_is_always_present_even_if_unwalkable() -> void:
	var d := RoadNetwork.distances_from({}, Vector2i(7, 7))
	assert_eq(d[Vector2i(7, 7)], 0)
