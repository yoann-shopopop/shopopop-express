extends GutTest
## Tests for BridgeFinder — finds a bridge placement that links a "one cell too far" block to the
## existing road network.

const BLUE := 0


func _road_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"road"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	return b


func _bridge() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"bridge"
	b.cells = BlockDefinition.make_line_cells(3)
	b.cell_types = [CellType.Kind.WATER, CellType.Kind.ROUTE, CellType.Kind.WATER]
	b.connectors = [Vector2i(0, 0), Vector2i(2, 0)] as Array[Vector2i]
	return b


func test_finds_a_bridge_that_links_block_to_network() -> void:
	var board := Board.new()
	board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)  # network road at (0,0)
	var result := BridgeFinder.find(board, _road_tile(), Vector2i(4, 0), 0, _bridge())
	assert_false(result.is_empty(), "a linking bridge exists")
	# Placing the bridge then the block must both succeed.
	assert_true(board.place(_bridge(), result["anchor"], result["rotation"], BLUE))
	assert_true(board.place(_road_tile(), Vector2i(4, 0), 0, BLUE))


func test_returns_empty_when_gap_is_too_large() -> void:
	var board := Board.new()
	board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	var result := BridgeFinder.find(board, _road_tile(), Vector2i(12, 0), 0, _bridge())
	assert_true(result.is_empty(), "no 3-cell bridge spans that gap")


func test_returns_empty_when_block_would_overlap() -> void:
	var board := Board.new()
	board.place(_road_tile(), Vector2i.ZERO, 0, BLUE)
	# Block dropped onto the existing cell — overlap, no bridge can fix that.
	var result := BridgeFinder.find(board, _road_tile(), Vector2i.ZERO, 0, _bridge())
	assert_true(result.is_empty())
