extends GutTest
## Tests for DeliverySetup — one delivery per tile carrying both a drive (urban) and a recipient
## (green); bridges (no urban/green) are skipped.


# A tile with an urban cell (drive) and a green cell (recipient).
func _qualifying_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"quartier"
	b.cells = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.URBAN, CellType.Kind.GREEN]
	b.connectors = [] as Array[Vector2i]
	return b


func _bridge() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"bridge"
	b.cells = BlockDefinition.make_line_cells(3)
	b.cell_types = [CellType.Kind.WATER, CellType.Kind.ROUTE, CellType.Kind.WATER]
	b.connectors = [] as Array[Vector2i]
	return b


# Places pieces unchecked (bypasses adjacency) so the test controls the layout directly.
func _board() -> Board:
	var board := Board.new()
	board.place(_qualifying_tile(), Vector2i(0, 0), 0, PlayerColor.Kind.RED, false)
	board.place(_qualifying_tile(), Vector2i(10, 0), 0, PlayerColor.Kind.BLUE, false)
	board.place(_bridge(), Vector2i(20, 0), 0, -1, false)
	return board


func test_builds_one_delivery_per_qualifying_tile() -> void:
	assert_eq(DeliverySetup.build(_board()).size(), 2, "two tiles, the bridge is skipped")


func test_drive_is_urban_and_recipient_is_green() -> void:
	var board := _board()
	var delivery: Delivery = DeliverySetup.build(board)[0]
	assert_eq(board.cell_type_at(delivery.drive_cell), CellType.Kind.URBAN)
	assert_eq(board.cell_type_at(delivery.recipient_cell), CellType.Kind.GREEN)
	assert_true(delivery.is_single_tile())
