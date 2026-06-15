extends GutTest
## Tests for DeliverySetup — RANDOM placement under per-tile quotas: 1 drive (URBAN) + 1 recipient
## (GREEN) per tile, paired 1-to-1 in shuffled order (so a recipient may sit on another tile). All cells
## reachable; cells walled off from the road are excluded so no delivery is ever undeliverable.


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# Tile A: route (0,0) + urban (0,-1) + green (-1,1). Distinct cells so two tiles can share anchor ZERO.
func _tile_a() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"tile_a"
	b.cells = [Vector2i(0, 0), Vector2i(0, -1), Vector2i(-1, 1)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	return b


# Tile B: route (1,0) (adjacent to A's road → connected) + urban (1,-1) + green (1,1).
func _tile_b() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"tile_b"
	b.cells = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(1, 1)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	return b


# Two tiles with connected roads, placed unchecked at anchor ZERO (absolute == local, no overlap).
func _connected_board() -> Board:
	var board := Board.new()
	board.place(_tile_a(), Vector2i.ZERO, 0, PlayerColor.Kind.RED, false)
	board.place(_tile_b(), Vector2i.ZERO, 0, PlayerColor.Kind.BLUE, false)
	return board


func test_drives_are_urban_recipients_green_and_reachable() -> void:
	var board := _connected_board()
	var walkable := RoadNetwork.walkable_from_board(board)
	var deliveries := DeliverySetup.build(board, _rng(1))
	assert_eq(deliveries.size(), 2, "two drives + two recipients available -> two deliveries")
	for delivery in deliveries:
		assert_eq(board.cell_type_at(delivery.drive_cell), CellType.Kind.URBAN, "drive on urban")
		assert_eq(board.cell_type_at(delivery.recipient_cell), CellType.Kind.GREEN, "recipient on green")
		assert_true(_adjacent_to_any(delivery.drive_cell, walkable), "drive reachable from a road")
		assert_true(_adjacent_to_any(delivery.recipient_cell, walkable), "recipient reachable from a road")


# A drive and its recipient may live on different tiles: with A holding only urban and B only green, the
# single delivery must span both — and score each tile to its own owner (drive=A=RED, recipient=B=BLUE).
func test_pairs_can_span_two_tiles() -> void:
	var board := Board.new()
	var a := BlockDefinition.new()
	a.id = &"a_urban"
	a.cells = [Vector2i(0, 0), Vector2i(0, -1)] as Array[Vector2i]
	a.cell_types = [CellType.Kind.ROUTE, CellType.Kind.URBAN]
	a.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	var b := BlockDefinition.new()
	b.id = &"b_green"
	b.cells = [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE, CellType.Kind.GREEN]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	board.place(a, Vector2i.ZERO, 0, PlayerColor.Kind.RED, false)
	board.place(b, Vector2i.ZERO, 0, PlayerColor.Kind.BLUE, false)

	var deliveries := DeliverySetup.build(board, _rng(1))
	assert_eq(deliveries.size(), 1)
	var d: Delivery = deliveries[0]
	assert_false(d.is_single_tile(), "drive and recipient on different tiles")
	assert_eq(d.drive_tile_owner(), PlayerColor.Kind.RED, "drive tile = A (red)")
	assert_eq(d.recipient_tile_owner(), PlayerColor.Kind.BLUE, "recipient tile = B (blue)")


func test_skips_cells_walled_off_from_the_road() -> void:
	var board := Board.new()
	var b := BlockDefinition.new()
	b.id = &"walled"
	b.cells = [Vector2i(0, 0), Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i]  # urban/green 3+ away
	b.cell_types = [CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	board.place(b, Vector2i.ZERO, 0, PlayerColor.Kind.RED, false)
	assert_eq(DeliverySetup.build(board, _rng(1)).size(), 0, "unreachable urban/green cells are not deliverable")


func test_respects_max_count() -> void:
	var deliveries := DeliverySetup.build(_connected_board(), _rng(1), 1)
	assert_eq(deliveries.size(), 1, "capped at max_count")


func test_deterministic_with_same_seed() -> void:
	var a := DeliverySetup.build(_connected_board(), _rng(7))
	var b := DeliverySetup.build(_connected_board(), _rng(7))
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].drive_cell, b[i].drive_cell, "same seed -> same drive")
		assert_eq(a[i].recipient_cell, b[i].recipient_cell, "same seed -> same recipient")


func test_excluded_cells_are_never_recipients() -> void:
	var board := _connected_board()
	var excluded := {Vector2i(-1, 1): true}  # tile A's green cell
	for delivery in DeliverySetup.build(board, _rng(3), -1, excluded):
		assert_ne(delivery.recipient_cell, Vector2i(-1, 1), "excluded green cell is kept out of recipients")


# Per-tile quota: a tile rich in urban/green cells still yields exactly one drive and one recipient.
func test_one_drive_and_one_recipient_per_tile() -> void:
	var board := Board.new()
	var b := BlockDefinition.new()
	b.id = &"rich_tile"
	# route + 2 urban (both road-adjacent) + 2 green (both road-adjacent).
	b.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)] as Array[Vector2i]
	b.cell_types = [
		CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.URBAN,
		CellType.Kind.GREEN, CellType.Kind.GREEN,
	]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	board.place(b, Vector2i.ZERO, 0, PlayerColor.Kind.RED, false)
	var deliveries := DeliverySetup.build(board, _rng(1))
	assert_eq(deliveries.size(), 1, "one tile -> one delivery (1 drive + 1 recipient)")
	assert_eq(board.cell_type_at(deliveries[0].drive_cell), CellType.Kind.URBAN)
	assert_eq(board.cell_type_at(deliveries[0].recipient_cell), CellType.Kind.GREEN)


func _adjacent_to_any(cell: Vector2i, walkable: Dictionary) -> bool:
	for neighbor in HexUtils.neighbors(cell):
		if walkable.has(neighbor):
			return true
	return false
