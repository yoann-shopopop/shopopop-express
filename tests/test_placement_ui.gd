extends GutTest
## Tests for PlacementUI's pure helpers. compute_turn_index derives the 1-based placement-turn number
## from the player's initial tile count, the tiles still in their tray, and whether this turn's block
## has been placed yet (placing removes the block from the tray, so the count must absorb that).


func test_first_turn_nothing_placed() -> void:
	# 3 tiles total, 3 still in tray, no block placed yet -> turn 1.
	assert_eq(PlacementUI.compute_turn_index(3, 3, false), 1)


func test_first_turn_after_placing() -> void:
	# Block placed this turn -> tray dropped to 2, but it's still turn 1.
	assert_eq(PlacementUI.compute_turn_index(3, 2, true), 1)


func test_second_turn_nothing_placed() -> void:
	assert_eq(PlacementUI.compute_turn_index(3, 2, false), 2)


func test_last_turn_after_placing() -> void:
	# Last tile placed -> tray empty, turn 3 of 3.
	assert_eq(PlacementUI.compute_turn_index(3, 0, true), 3)


func test_last_turn_nothing_placed() -> void:
	assert_eq(PlacementUI.compute_turn_index(3, 1, false), 3)


func test_clamped_to_at_least_one() -> void:
	# Defensive: never report turn 0 or negative.
	assert_eq(PlacementUI.compute_turn_index(0, 0, false), 1)
