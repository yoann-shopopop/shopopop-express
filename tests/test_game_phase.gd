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

# A character (kept for parity with real players; scoring now uses player.color).
func _red_character() -> CharacterDefinition:
	var c := CharacterDefinition.new()
	c.colors = [PlayerColor.Kind.RED]
	return c


# A phase with one RED tile and a delivery drive=(1,0) / recipient=(2,0) (both road cells, walkable).
# One RED player starting on the tile's green cell (0,0). The delivery has a recipient clipped.
func _phase_with_delivery() -> GamePhase:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, tile)
	player.character = _red_character()
	var piece: PlacedPiece = board.pieces()[0]
	var delivery := Delivery.new(Vector2i(1, 0), Vector2i(2, 0), [piece] as Array[PlacedPiece])
	delivery.destinataire = DestinataireDefinition.new()  # reservable
	return GamePhase.new([player] as Array[Player], board, [delivery] as Array[Delivery])


func test_reserve_delivery_on_the_tile_sets_reserve() -> void:
	var phase := _phase_with_delivery()
	phase.begin_movement(3)  # pawn on (0,0), which belongs to the tile
	assert_true(phase.reserve_delivery(), "reservable from the tile")
	assert_eq(phase.available_deliveries().size(), 0, "no longer available")
	assert_eq(phase.deliveries_in_flight(0).size(), 1)


func test_cannot_reserve_outside_deplacement() -> void:
	var phase := _phase_with_delivery()
	assert_false(phase.reserve_delivery(), "still PLANIFICATION")


func test_stepping_onto_the_drive_cell_sets_en_cours() -> void:
	var phase := _phase_with_delivery()
	phase.begin_movement(3)
	phase.reserve_delivery()
	phase.try_step(Vector2i(1, 0))  # the drive cell
	assert_eq(phase.deliveries_in_flight(0)[0].status, DeliveryStatus.Kind.EN_COURS)


func test_reserving_while_on_the_drive_cell_jumps_to_en_cours() -> void:
	var phase := _phase_with_delivery()
	phase.begin_movement(3)
	phase.try_step(Vector2i(1, 0))  # step onto the drive cell first (no reservation yet)
	assert_true(phase.reserve_delivery(), "still reservable from the drive cell")
	assert_eq(phase.deliveries_in_flight(0)[0].status, DeliveryStatus.Kind.EN_COURS,
		"reserving on the drive cell transitions straight to EN_COURS")


func test_stepping_onto_the_recipient_scores_and_is_free() -> void:
	var phase := _phase_with_delivery()
	var player := phase.current_player()
	phase.begin_movement(3)
	phase.reserve_delivery()
	phase.try_step(Vector2i(1, 0))  # drive -> EN_COURS
	phase.try_step(Vector2i(2, 0))  # recipient -> delivered
	assert_eq(phase.score_of(player), 25, "single tile that is mine")
	assert_eq(phase.movement().remaining(), 1, "two steps from a budget of 3, reservation is free")
	assert_true(phase.is_finished(), "the only delivery is done, no recycling")


func test_cannot_reserve_more_than_two_in_flight() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, tile)
	player.character = _red_character()
	var piece: PlacedPiece = board.pieces()[0]
	# Three deliveries pinned to the same tile (unrealistic, but exercises the cap purely).
	var deliveries: Array[Delivery] = []
	for i in 3:
		var d := Delivery.new(Vector2i(1, 0), Vector2i(2, 0), [piece] as Array[PlacedPiece])
		d.destinataire = DestinataireDefinition.new()
		deliveries.append(d)
	var phase := GamePhase.new([player] as Array[Player], board, deliveries)
	phase.begin_movement(3)
	# Mark two as already in flight for player 0.
	deliveries[0].status = DeliveryStatus.Kind.RESERVE
	deliveries[0].reserved_by = 0
	deliveries[1].status = DeliveryStatus.Kind.EN_COURS
	deliveries[1].reserved_by = 0
	assert_eq(phase.deliveries_in_flight(0).size(), 2)
	assert_null(phase.reservable_delivery(), "cap of 2 reached")
	assert_false(phase.reserve_delivery())


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


# --- Deliveries fed by a DeliveryGenerator (recycling) ----------------------

# One RED tile, delivery drive (1,0) / recipient (2,0), fed by a generator with [param recipient_count]
# recipients (slot count 1). Returns { "phase", "delivery" }.
func _phase_with_generator(recipient_count: int) -> Dictionary:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, tile)
	player.character = _red_character()
	var piece: PlacedPiece = board.pieces()[0]
	var enseignes := [EnseigneDefinition.new()] as Array[EnseigneDefinition]
	var recipients: Array[DestinataireDefinition] = []
	for i in recipient_count:
		var d := DestinataireDefinition.new()
		d.id = StringName("d%d" % i)
		recipients.append(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var generator := DeliveryGenerator.new(enseignes, recipients, 1, rng)
	var delivery := Delivery.new(Vector2i(1, 0), Vector2i(2, 0), [piece] as Array[PlacedPiece])
	delivery.enseigne = generator.combos()[0].enseigne
	delivery.destinataire = generator.combos()[0].destinataire
	var phase := GamePhase.new([player] as Array[Player], board, [delivery] as Array[Delivery], generator)
	return {"phase": phase, "delivery": delivery}


# Reserves on the start tile then walks drive->recipient (all free now).
func _deliver_once(phase: GamePhase) -> void:
	phase.begin_movement(3)
	phase.reserve_delivery()
	phase.try_step(Vector2i(1, 0))
	phase.try_step(Vector2i(2, 0))


func test_delivery_recycles_and_game_continues_when_pool_has_spares() -> void:
	var ctx := _phase_with_generator(2)  # 1 used at init, 1 spare
	var phase: GamePhase = ctx["phase"]
	var delivery: Delivery = ctx["delivery"]
	_deliver_once(phase)
	assert_eq(delivery.status, DeliveryStatus.Kind.DISPONIBLE, "recycled, available again")
	assert_not_null(delivery.destinataire, "a new recipient was clipped")
	assert_false(phase.is_finished())
	assert_eq(phase.available_deliveries().size(), 1)


func test_game_finishes_when_the_recipient_pool_is_exhausted() -> void:
	var ctx := _phase_with_generator(1)  # no spare
	var phase: GamePhase = ctx["phase"]
	var delivery: Delivery = ctx["delivery"]
	_deliver_once(phase)
	assert_null(delivery.destinataire, "pool empty -> drive left free")
	assert_eq(delivery.status, DeliveryStatus.Kind.DISPONIBLE)
	assert_true(phase.is_finished())
