extends GutTest
## Tests for BlockDefinition — a modular board piece described by axial cell offsets.

const ANCHOR := Vector2i(5, -3)


func _make_block(cells: Array[Vector2i]) -> BlockDefinition:
	var block := BlockDefinition.new()
	block.cells = cells
	return block


func test_hexagon_side_three_has_19_cells() -> void:
	var cells := BlockDefinition.make_hexagon_cells(3)
	assert_eq(cells.size(), 19, "a side-3 hexagon block is 19 cells")


func test_hexagon_cells_are_unique() -> void:
	var cells := BlockDefinition.make_hexagon_cells(3)
	var unique := {}
	for cell in cells:
		unique[cell] = true
	assert_eq(unique.size(), cells.size(), "no duplicate cells")


func test_hexagon_cells_stay_within_radius() -> void:
	# Side 3 hexagon => every cell is at most 2 steps from the center.
	for cell in BlockDefinition.make_hexagon_cells(3):
		assert_lte(HexUtils.distance(Vector2i.ZERO, cell), 2)


func test_line_length_three_has_3_cells() -> void:
	var cells := BlockDefinition.make_line_cells(3)
	assert_eq(cells.size(), 3, "a length-3 bridge is 3 cells")


func test_line_cells_are_contiguous() -> void:
	var cells := BlockDefinition.make_line_cells(3)
	assert_true(HexUtils.are_adjacent(cells[0], cells[1]))
	assert_true(HexUtils.are_adjacent(cells[1], cells[2]))


func test_get_cells_translates_to_anchor() -> void:
	var block := _make_block([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i])
	var placed := block.get_cells(ANCHOR, 0)
	assert_eq(placed[0], ANCHOR)
	assert_eq(placed[1], ANCHOR + Vector2i(1, 0))


func test_get_cells_count_is_stable_under_rotation() -> void:
	var block := _make_block(BlockDefinition.make_hexagon_cells(3))
	assert_eq(block.get_cells(ANCHOR, 2).size(), 19, "rotation keeps the cell count")


func test_rotating_a_line_changes_its_orientation() -> void:
	var block := _make_block(BlockDefinition.make_line_cells(3))
	var straight := block.get_cells(Vector2i.ZERO, 0)
	var turned := block.get_cells(Vector2i.ZERO, 1)
	assert_ne(straight, turned, "a rotated bridge points a different way")
