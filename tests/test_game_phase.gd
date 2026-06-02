extends GutTest
## Tests for GamePhase — the turn loop after setup: planning -> movement -> end of turn, round-robin.
## Pure logic: the dice budget is injected (no DiceRoller, no nodes).


# A tile: green start at (0,0), a road running (1,0)->(2,0). Green is on the edge of the road.
func _tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"start_tile"
	b.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.ROUTE]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	return b


func _player(index: int, color: int, start_block: BlockDefinition) -> Player:
	var p := Player.new(color)
	p.index = index
	p.start_block = start_block
	p.start_cell = Vector2i(0, 0)  # the green cell
	return p


# A board with the tile placed at the origin, and two players starting on its green cell.
func _phase() -> GamePhase:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var players: Array[Player] = [
		_player(0, PlayerColor.Kind.BLUE, tile),
		_player(1, PlayerColor.Kind.RED, tile),
	]
	return GamePhase.new(players, board)


func test_starts_with_the_first_player_planning() -> void:
	var phase := _phase()
	assert_eq(phase.current_player().index, 0)
	assert_eq(phase.current_subphase(), GamePhase.SubPhase.PLANIFICATION)


func test_pawn_starts_on_its_green_start_cell() -> void:
	var phase := _phase()
	assert_eq(phase.position_of(phase.current_player()), Vector2i(0, 0))


func test_begin_movement_enters_deplacement() -> void:
	var phase := _phase()
	phase.begin_movement(2)
	assert_eq(phase.current_subphase(), GamePhase.SubPhase.DEPLACEMENT)
	assert_eq(phase.movement().remaining(), 2)


func test_try_step_walks_the_pawn_onto_an_adjacent_road() -> void:
	var phase := _phase()
	phase.begin_movement(2)
	assert_true(phase.try_step(Vector2i(1, 0)), "green start -> adjacent road")
	assert_eq(phase.position_of(phase.current_player()), Vector2i(1, 0))


func test_try_step_is_rejected_before_movement_begins() -> void:
	var phase := _phase()
	assert_false(phase.try_step(Vector2i(1, 0)), "cannot step while planning")


func test_end_turn_advances_to_the_next_player() -> void:
	var phase := _phase()
	phase.end_turn()
	assert_eq(phase.current_player().index, 1)
	assert_eq(phase.current_subphase(), GamePhase.SubPhase.PLANIFICATION)


func test_end_turn_wraps_around_round_robin() -> void:
	var phase := _phase()
	phase.end_turn()
	phase.end_turn()
	assert_eq(phase.current_player().index, 0)


# --- Deliveries -------------------------------------------------------------

# A character owning RED, so a RED tile scores for its carrier.
func _red_character() -> CharacterDefinition:
	var c := CharacterDefinition.new()
	c.colors = [PlayerColor.Kind.RED]
	return c


# A phase with one RED tile and a delivery whose drive=(1,0) and recipient=(2,0) (both road cells, so
# the pawn can stand on them). One player owning RED.
func _phase_with_delivery() -> GamePhase:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, tile)
	player.character = _red_character()
	var piece: PlacedPiece = board.pieces()[0]
	var delivery := Delivery.new(Vector2i(1, 0), Vector2i(2, 0), [piece] as Array[PlacedPiece])
	return GamePhase.new([player] as Array[Player], board, [delivery] as Array[Delivery])


func test_select_delivery_reserves_it() -> void:
	var phase := _phase_with_delivery()
	var d := phase.available_deliveries()[0]
	phase.select_delivery(d)
	assert_eq(phase.current_delivery(), d)
	assert_eq(phase.available_deliveries().size(), 0, "reserved, no longer available")


func test_pickup_costs_one_extra_step() -> void:
	var phase := _phase_with_delivery()
	phase.select_delivery(phase.available_deliveries()[0])
	phase.begin_movement(3)
	phase.try_step(Vector2i(1, 0))  # onto the drive cell, budget now 2
	assert_true(phase.confirm_pickup())
	assert_true(phase.current_delivery().picked_up)
	assert_eq(phase.movement().remaining(), 1, "pickup costs +1 step")


func test_delivering_scores_and_finishes_the_game() -> void:
	var phase := _phase_with_delivery()
	var player := phase.current_player()
	phase.select_delivery(phase.available_deliveries()[0])
	phase.begin_movement(3)
	phase.try_step(Vector2i(1, 0))
	phase.confirm_pickup()
	phase.try_step(Vector2i(2, 0))  # onto the recipient cell
	assert_true(phase.confirm_delivery())
	assert_eq(phase.score_of(player), 20, "single owned tile = 20")
	assert_true(phase.is_finished(), "the only delivery is done")


# --- Events & powers --------------------------------------------------------

# A tile with an EVENT (rainbow) cell at (2,0), reachable by road from the green start.
func _event_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"event_tile"
	b.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.EVENT]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	return b


func _phase_with_event() -> GamePhase:
	var board := Board.new()
	var tile := _event_tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, tile)
	var c := CharacterDefinition.new()
	c.power_id = &"bonne_marcheuse"
	player.character = c
	return GamePhase.new([player] as Array[Player], board)


func test_stepping_onto_an_event_cell_emits_event_triggered() -> void:
	var phase := _phase_with_event()
	phase.begin_movement(3)
	watch_signals(phase)
	phase.try_step(Vector2i(1, 0))
	phase.try_step(Vector2i(2, 0))  # the EVENT cell
	assert_signal_emitted_with_parameters(phase, "event_triggered", [Vector2i(2, 0)])


func test_apply_event_bonus_cases_extends_movement() -> void:
	var phase := _phase_with_event()
	phase.begin_movement(2)
	var card := EventCardDefinition.new()
	card.effect = EventCardDefinition.Effect.BONUS_CASES
	card.amount = 3
	phase.apply_event(card)
	assert_eq(phase.movement().remaining(), 5)


func test_use_power_applies_once() -> void:
	var phase := _phase_with_event()
	phase.begin_movement(2)
	assert_true(phase.use_power())
	assert_eq(phase.movement().remaining(), 4, "bonne marcheuse +2")
	assert_false(phase.use_power(), "one-shot")
