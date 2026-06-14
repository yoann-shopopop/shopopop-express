extends GutTest
## Tests for Board — placement model with connector-based (road-to-road) adjacency.

const BLUE := 0
const RED := 1

var _board: Board


func before_each() -> void:
	_board = Board.new()


# A 1-cell road tile whose single cell is a connector.
func _road_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"road"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	return b


# A 1-cell green tile with no connectors (cannot link road-to-road).
func _green_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"green"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.GREEN]
	b.connectors = [] as Array[Vector2i]
	return b


# Bridge: water-road-water, connectors at the two ends.
func _bridge() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"bridge"
	b.cells = BlockDefinition.make_line_cells(3)
	b.cell_types = [CellType.Kind.WATER, CellType.Kind.ROUTE, CellType.Kind.WATER]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]  # only the central road cell connects
	return b


func test_new_board_is_empty() -> void:
	assert_true(_board.is_empty())


func test_first_piece_can_be_placed_anywhere() -> void:
	assert_true(_board.can_place(_road_tile(), Vector2i(9, -3), 0))


func test_placing_records_owner_and_type() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	assert_eq(_board.cell_type_at(Vector2i.ZERO), CellType.Kind.ROUTE)
	assert_eq(_board.owner_at(Vector2i.ZERO), BLUE)
	assert_eq(_board.pieces().size(), 1)


func test_overlapping_placement_is_rejected() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	assert_false(_board.can_place(_road_tile(), Vector2i.ZERO, 0))


func test_road_touching_road_is_accepted() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	# A road tile whose connector (its cell) is adjacent to the existing road connector.
	assert_true(_board.can_place(_road_tile(), Vector2i(1, 0), 0))


func test_non_road_cell_touching_is_rejected() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	# Green tile is adjacent to the road but has no connector -> no road-to-road link.
	assert_false(_board.can_place(_green_tile(), Vector2i(1, 0), 0))


func test_connector_present_but_not_adjacent_is_rejected() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	# Connector at (2,0) is not a neighbor of the existing connector (0,0), and does not touch it.
	assert_false(_board.can_place(_road_tile(), Vector2i(2, 0), 0))


func test_bridge_connects_only_via_its_central_road() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	# Central road cell (0,1) touches the road connector (0,0) -> OK.
	assert_true(_board.can_place(_bridge(), Vector2i(-1, 1), 0))
	# Here only a water end would touch the road (center two cells away) -> rejected.
	assert_false(_board.can_place(_bridge(), Vector2i(1, 0), 0))


func test_place_returns_false_and_does_not_mutate_when_invalid() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	var ok := _board.place(_green_tile(), Vector2i(1, 0), 0, RED)
	assert_false(ok)
	assert_eq(_board.pieces().size(), 1, "board left unchanged")


func test_cells_of_type_lists_cells_with_that_type() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	assert_eq(_board.cells_of_type(CellType.Kind.ROUTE), [Vector2i.ZERO] as Array[Vector2i])
	assert_eq(_board.cells_of_type(CellType.Kind.GREEN), [] as Array[Vector2i])


func test_cells_of_type_is_empty_on_a_new_board() -> void:
	assert_eq(_board.cells_of_type(CellType.Kind.ROUTE), [] as Array[Vector2i])


func test_piece_at_returns_the_piece_covering_a_cell() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	assert_eq(_board.piece_at(Vector2i.ZERO), _board.pieces()[0])


func test_piece_at_returns_null_on_an_empty_cell() -> void:
	assert_null(_board.piece_at(Vector2i(5, 5)))


func test_remove_piece_frees_its_cells() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	assert_true(_board.remove_piece(_board.pieces()[0]))
	assert_true(_board.is_empty())
	assert_false(_board.is_occupied(Vector2i.ZERO))
	assert_eq(_board.cell_type_at(Vector2i.ZERO), -1)


func test_remove_piece_clears_its_connector_so_the_cell_is_reusable() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	_board.place(_road_tile(), Vector2i(1, 0), 0, RED)
	assert_true(_board.remove_piece(_board.pieces()[1]))
	assert_eq(_board.pieces().size(), 1)
	# (1,0) is free again and still links road-to-road to the remaining tile at (0,0).
	assert_true(_board.can_place(_road_tile(), Vector2i(1, 0), 0))


func test_remove_piece_not_on_board_returns_false() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	var ghost := PlacedPiece.new(_road_tile(), Vector2i(5, 5), 0, RED)
	assert_false(_board.remove_piece(ghost))
	assert_eq(_board.pieces().size(), 1)


func test_remove_piece_emits_changed() -> void:
	_board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	watch_signals(_board)
	_board.remove_piece(_board.pieces()[0])
	assert_signal_emitted(_board, "changed")
