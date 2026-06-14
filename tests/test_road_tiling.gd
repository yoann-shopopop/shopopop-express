extends GutTest
## Tests for RoadTiling — picks the road texture (straight/T), rotation and mirror from the set of
## directions a road cell connects to. Directions use HexUtils indices (N=2, S=5, NE=1, NW=3, …).


func test_straight_north_south_is_variant1_no_rotation() -> void:
	var r := RoadTiling.classify([2, 5])
	assert_eq(r["variant"], RoadTiling.STRAIGHT)
	assert_eq(RoadTiling.connected_dirs(r["variant"], r["steps"], r["flip"]), [2, 5])


func test_straight_other_axis_round_trips() -> void:
	var r := RoadTiling.classify([0, 3])
	assert_eq(r["variant"], RoadTiling.STRAIGHT)
	assert_eq(RoadTiling.connected_dirs(r["variant"], r["steps"], r["flip"]), [0, 3])


func test_dead_end_renders_as_a_straight_axis() -> void:
	var r := RoadTiling.classify([2])
	assert_eq(r["variant"], RoadTiling.STRAIGHT)
	# A dead-end is drawn as the straight road on its axis (N–S here).
	assert_eq(RoadTiling.connected_dirs(r["variant"], r["steps"], r["flip"]), [2, 5])


func test_t_branch_round_trips() -> void:
	var r := RoadTiling.classify([1, 2, 5])
	assert_eq(r["variant"], RoadTiling.T)
	assert_eq(RoadTiling.connected_dirs(r["variant"], r["steps"], r["flip"]), [1, 2, 5])


func test_mirrored_t_branch_uses_flip() -> void:
	var r := RoadTiling.classify([2, 3, 5])
	assert_eq(r["variant"], RoadTiling.T)
	assert_true(r["flip"])
	assert_eq(RoadTiling.connected_dirs(r["variant"], r["steps"], r["flip"]), [2, 3, 5])


func test_input_order_does_not_matter() -> void:
	assert_eq(RoadTiling.classify([5, 2]), RoadTiling.classify([2, 5]))
