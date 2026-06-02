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


func test_edge_centers_are_six_cells_at_radius() -> void:
	var centers := BlockDefinition.hexagon_edge_centers(2)
	assert_eq(centers.size(), 6, "a hexagon has 6 edge centers")
	for cell in centers:
		assert_eq(HexUtils.distance(Vector2i.ZERO, cell), 2, "edge center sits on the rim")


func test_typed_cells_pair_each_cell_with_its_type() -> void:
	var block := BlockDefinition.new()
	block.cells = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	block.cell_types = [CellType.Kind.ROUTE, CellType.Kind.GREEN]
	var typed := block.get_typed_cells(Vector2i(5, -3), 0)
	assert_eq(typed.size(), 2)
	assert_eq(typed[0]["cell"], Vector2i(5, -3))
	assert_eq(typed[0]["type"], CellType.Kind.ROUTE)
	assert_eq(typed[1]["cell"], Vector2i(6, -3))
	assert_eq(typed[1]["type"], CellType.Kind.GREEN)


func test_typed_cells_keep_their_type_after_rotation() -> void:
	var block := BlockDefinition.new()
	block.cells = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	block.cell_types = [CellType.Kind.ROUTE, CellType.Kind.GREEN]
	var typed := block.get_typed_cells(Vector2i.ZERO, 2)
	# The ROUTE stays on the rotated first cell, GREEN on the rotated second cell.
	assert_eq(typed[0]["cell"], HexUtils.rotate(Vector2i(0, 0), 2))
	assert_eq(typed[0]["type"], CellType.Kind.ROUTE)
	assert_eq(typed[1]["cell"], HexUtils.rotate(Vector2i(1, 0), 2))
	assert_eq(typed[1]["type"], CellType.Kind.GREEN)


func test_connectors_are_translated_and_rotated() -> void:
	var block := BlockDefinition.new()
	block.cells = BlockDefinition.make_line_cells(3)
	block.connectors = [Vector2i(0, 0), Vector2i(2, 0)] as Array[Vector2i]
	var anchor := Vector2i(4, 1)
	var conns := block.get_connectors(anchor, 0)
	assert_eq(conns[0], anchor)
	assert_eq(conns[1], anchor + Vector2i(2, 0))
	# After a full turn the connectors come back to the same absolute cells.
	assert_eq(block.get_connectors(anchor, 6), conns)
