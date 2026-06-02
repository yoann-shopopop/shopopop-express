extends GutTest
## Tests for Board — the placement rules model (no rendering).

var _board: Board


func before_each() -> void:
	_board = Board.new()


func _hex() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"hex19"
	b.cells = BlockDefinition.make_hexagon_cells(3)
	return b


func _bridge() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"bridge3"
	b.cells = BlockDefinition.make_line_cells(3)
	return b


func test_new_board_is_empty() -> void:
	assert_true(_board.is_empty())


func test_first_block_can_be_placed_anywhere() -> void:
	assert_true(_board.can_place(_hex(), Vector2i(10, -4), 0))


func test_placing_marks_all_cells_occupied() -> void:
	_board.place(_hex(), Vector2i.ZERO, 0)
	assert_false(_board.is_empty())
	assert_eq(_board.occupied_cells().size(), 19)


func test_overlapping_placement_is_rejected() -> void:
	_board.place(_hex(), Vector2i.ZERO, 0)
	assert_false(_board.can_place(_hex(), Vector2i.ZERO, 0), "cannot overlap existing cells")


func test_disconnected_second_block_is_rejected() -> void:
	_board.place(_hex(), Vector2i.ZERO, 0)
	assert_false(_board.can_place(_bridge(), Vector2i(100, 0), 0), "must touch an existing block")


func test_adjacent_second_block_is_accepted() -> void:
	_board.place(_hex(), Vector2i.ZERO, 0)
	# (3,0) is free and adjacent to the occupied edge cell (2,0).
	assert_true(_board.can_place(_bridge(), Vector2i(3, 0), 0))


func test_place_returns_false_and_does_not_mutate_when_invalid() -> void:
	_board.place(_hex(), Vector2i.ZERO, 0)
	var before := _board.occupied_cells().size()
	var ok := _board.place(_hex(), Vector2i.ZERO, 0)
	assert_false(ok, "invalid placement is refused")
	assert_eq(_board.occupied_cells().size(), before, "board left unchanged")


func test_place_returns_true_when_valid() -> void:
	assert_true(_board.place(_hex(), Vector2i.ZERO, 0))
