extends GutTest
## Tests for DeliverySetup — one delivery per tile carrying both a road-reachable drive (urban) and a
## road-reachable recipient (green); bridges (no urban/green) and tiles whose urban/green cells are
## walled off from the road are skipped.


# A tile with a road at (0,0) and an urban (drive) + green (recipient) cell on its edges, both
# adjacent to the road so they are reachable. Neighbours of (0,0) include (1,0) and (0,1).
func _qualifying_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"quartier"
	b.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	return b


# A tile whose urban/green cells are NOT adjacent to any road (the road sits two cells away). These
# cells can never be stepped onto, so the tile must yield no delivery (else the game could not end).
func _unreachable_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"walled_off"
	b.cells = [Vector2i(0, 0), Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
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


# Reachability guard: a tile whose urban/green cells have no road neighbour yields no delivery, so the
# game can never stall on an undeliverable parcel (is_finished would otherwise never hold).
func test_skips_tiles_with_unreachable_drive_or_recipient() -> void:
	var board := Board.new()
	board.place(_unreachable_tile(), Vector2i(0, 0), 0, PlayerColor.Kind.RED, false)
	assert_eq(DeliverySetup.build(board).size(), 0, "walled-off urban/green cells are not deliverable")


func test_chosen_cells_are_reachable_from_the_road_network() -> void:
	var board := _board()
	var walkable := RoadNetwork.walkable_from_board(board)
	for delivery in DeliverySetup.build(board):
		var augmented := walkable.duplicate()
		augmented[delivery.drive_cell] = true
		assert_true(_adjacent_to_any(delivery.drive_cell, walkable), "drive reachable from a road")
		assert_true(_adjacent_to_any(delivery.recipient_cell, augmented), "recipient reachable from road or drive")


func _adjacent_to_any(cell: Vector2i, walkable: Dictionary) -> bool:
	for neighbor in HexUtils.neighbors(cell):
		if walkable.has(neighbor):
			return true
	return false
