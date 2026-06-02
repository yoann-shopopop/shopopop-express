extends GutTest
## Tests for RoadNetwork — the walkable set (roads + event cells) derived from a Board.


# A 5-cell line covering every terrain type, placeable as the first (free) piece.
func _mixed_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"mixed"
	b.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i]
	b.cell_types = [
		CellType.Kind.ROUTE,
		CellType.Kind.GREEN,
		CellType.Kind.URBAN,
		CellType.Kind.WATER,
		CellType.Kind.EVENT,
	]
	b.connectors = [] as Array[Vector2i]
	return b


func _board_with_mixed_tile() -> Board:
	var board := Board.new()
	board.place(_mixed_tile(), Vector2i.ZERO, 0, 0)
	return board


func test_walkable_includes_route_and_event_only() -> void:
	var walkable := RoadNetwork.walkable_from_board(_board_with_mixed_tile())
	assert_true(walkable.has(Vector2i(0, 0)), "route is walkable")
	assert_true(walkable.has(Vector2i(4, 0)), "event is walkable")
	assert_false(walkable.has(Vector2i(1, 0)), "green excluded")
	assert_false(walkable.has(Vector2i(2, 0)), "urban excluded")
	assert_false(walkable.has(Vector2i(3, 0)), "water excluded")


func test_walkable_is_empty_on_a_new_board() -> void:
	assert_eq(RoadNetwork.walkable_from_board(Board.new()).size(), 0)


func test_walkable_excluding_removes_closed_cells() -> void:
	var closed := {Vector2i(0, 0): true}
	var walkable := RoadNetwork.walkable_excluding(_board_with_mixed_tile(), closed)
	assert_false(walkable.has(Vector2i(0, 0)), "closed route is removed")
	assert_true(walkable.has(Vector2i(4, 0)), "non-closed event stays walkable")
