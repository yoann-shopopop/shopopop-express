extends GutTest
## Tests for PlayerPanel — the per-player stat row (score, in-flight gauge, power status) that
## replaced the old bare order-of-seats color chips in PlayHud.


func _tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"t"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.GREEN]
	b.connectors = [] as Array[Vector2i]
	return b


func _player(index: int, color: int, start_block: BlockDefinition) -> Player:
	var p := Player.new(color)
	p.index = index
	p.start_block = start_block
	p.start_cell = Vector2i(0, 0)
	return p


func _phase_with_players() -> Dictionary:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var p0 := _player(0, PlayerColor.Kind.BLUE, tile)
	var p1 := _player(1, PlayerColor.Kind.RED, tile)
	var players: Array[Player] = [p0, p1]
	var phase := GamePhase.new(players, board)
	return {"phase": phase, "players": players, "p0": p0, "p1": p1}


func test_build_creates_one_card_per_player_without_error() -> void:
	var ctx := _phase_with_players()
	var panel := PlayerPanel.new()
	add_child_autofree(panel)
	panel.build(ctx["players"])
	panel.refresh(ctx["phase"], ctx["p0"])
	pass_test("built and refreshed without error for 2 players")


func test_refresh_shows_zero_in_flight_gauge_when_nothing_reserved() -> void:
	var ctx := _phase_with_players()
	var panel := PlayerPanel.new()
	add_child_autofree(panel)
	panel.build(ctx["players"])
	panel.refresh(ctx["phase"], ctx["p0"])
	assert_eq(panel._flight_labels[0].text, "0/2 en vol")


func test_refresh_reflects_a_reservation_in_the_gauge() -> void:
	var board := Board.new()
	var tile := BlockDefinition.new()
	tile.id = &"drive_tile"
	tile.cells = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	tile.cell_types = [CellType.Kind.GREEN, CellType.Kind.URBAN]
	tile.connectors = [] as Array[Vector2i]
	board.place(tile, Vector2i.ZERO, 0, 0)
	var piece: PlacedPiece = board.pieces()[0]
	var destinataire := DestinataireDefinition.new()
	var delivery := Delivery.new(Vector2i(1, 0), Vector2i(1, 0), [piece] as Array[PlacedPiece])
	delivery.destinataire = destinataire
	var p0 := _player(0, PlayerColor.Kind.BLUE, tile)
	var p1 := _player(1, PlayerColor.Kind.RED, tile)
	var players: Array[Player] = [p0, p1]
	var phase := GamePhase.new(players, board, [delivery] as Array[Delivery])
	phase.begin_movement(0)
	phase.reserve_delivery()

	var panel := PlayerPanel.new()
	add_child_autofree(panel)
	panel.build(players)
	panel.refresh(phase, p0)
	assert_eq(panel._flight_labels[0].text, "1/2 en vol")
	assert_eq(panel._flight_labels[1].text, "0/2 en vol")
