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


func test_round_number_increments_when_play_wraps_to_the_first_seat() -> void:
	var phase := _phase()  # two players
	assert_eq(phase.round_number(), 1)
	phase.end_turn()
	assert_eq(phase.round_number(), 1, "still round 1 mid-round")
	phase.end_turn()
	assert_eq(phase.round_number(), 2, "wrapped back to seat 0 -> round 2")


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


# The drive sits on an URBAN cell and the recipient on a GREEN cell — neither is a road. The pawn must
# still be able to step onto them (off the road) to pick up / deliver. Regression: with a roads-only
# walkable set they were unreachable, so EN_COURS/LIVREE never triggered in the real game.
func test_pawn_can_reach_a_drive_cell_off_the_road() -> void:
	var board := Board.new()
	var b := BlockDefinition.new()
	b.id = &"drive_tile"
	b.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.URBAN]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	board.place(b, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, b)
	player.character = _red_character()
	var piece: PlacedPiece = board.pieces()[0]
	# drive on the urban cell (2,0) — off the road; recipient on the green start (0,0).
	var delivery := Delivery.new(Vector2i(2, 0), Vector2i(0, 0), [piece] as Array[PlacedPiece])
	delivery.destinataire = DestinataireDefinition.new()
	var phase := GamePhase.new([player] as Array[Player], board, [delivery] as Array[Delivery])
	phase.begin_movement(3)
	phase.reserve_delivery()  # pawn on the green start (0,0), which belongs to the tile
	assert_true(phase.try_step(Vector2i(1, 0)), "step onto the road")
	assert_true(phase.try_step(Vector2i(2, 0)), "the urban drive cell must be reachable")
	assert_eq(phase.deliveries_in_flight(0)[0].status, DeliveryStatus.Kind.EN_COURS,
		"reaching the drive cell sets EN_COURS")


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


func test_replay_event_keeps_the_same_player_and_round() -> void:
	var phase := _phase()  # two players, player 0 is current
	phase.begin_movement(3)
	var card := EventCardDefinition.new()
	card.effect = EventCardDefinition.Effect.REJOUER
	phase.apply_event(card)
	var who := phase.current_player().index
	var round_before := phase.round_number()
	phase.end_turn()
	assert_eq(phase.current_player().index, who, "Tous les Feux au Vert : le même joueur rejoue")
	assert_eq(phase.round_number(), round_before, "pas d'avance de manche sur un rejoue")
	assert_eq(phase.current_subphase(), GamePhase.SubPhase.PLANIFICATION)


func test_turn_without_replay_advances_to_next_player() -> void:
	var phase := _phase()
	phase.begin_movement(3)
	phase.end_turn()
	assert_eq(phase.current_player().index, 1, "sans rejoue : on passe au joueur suivant")


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


func test_deliveries_remaining_counts_clipped_plus_pooled_recipients() -> void:
	var ctx := _phase_with_generator(2)  # 1 clipped at init + 1 spare in the pool
	var phase: GamePhase = ctx["phase"]
	assert_eq(phase.deliveries_remaining(), 2)
	_deliver_once(phase)
	assert_eq(phase.deliveries_remaining(), 1, "one delivered, the recycled recipient remains")


func test_deliveries_remaining_reaches_zero_exactly_when_finished() -> void:
	var ctx := _phase_with_generator(1)
	var phase: GamePhase = ctx["phase"]
	assert_eq(phase.deliveries_remaining(), 1)
	_deliver_once(phase)
	assert_eq(phase.deliveries_remaining(), 0)
	assert_true(phase.is_finished())


# --- Super-powers (the four that were stubbed + the two dead-flag ones) ------

func _char_with_power(power_id: StringName) -> CharacterDefinition:
	var c := CharacterDefinition.new()
	c.colors = [PlayerColor.Kind.RED]
	c.power_id = power_id
	return c


# Two players on one tile; player 0 holds Dépassement. Returns { phase, p0, p1 }.
func _depassement_setup() -> Dictionary:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var p0 := _player(0, PlayerColor.Kind.RED, tile)
	p0.character = _char_with_power(&"depassement")
	var p1 := _player(1, PlayerColor.Kind.BLUE, tile)
	var phase := GamePhase.new([p0, p1] as Array[Player], board)
	return {"phase": phase, "p0": p0, "p1": p1}


func test_depassement_swaps_pawn_cells_and_spends_the_power() -> void:
	var s := _depassement_setup()
	var phase: GamePhase = s["phase"]
	phase.begin_movement(3)
	phase.try_step(Vector2i(1, 0))  # player 0 -> (1,0); player 1 still on (0,0)
	assert_true(phase.swap_positions(1))
	assert_eq(phase.position_of(s["p0"]), Vector2i(0, 0), "player 0 took player 1's cell")
	assert_eq(phase.position_of(s["p1"]), Vector2i(1, 0), "player 1 took player 0's cell")
	assert_true(s["p0"].power_used)
	assert_false(phase.swap_positions(1), "one-shot")


func test_coup_accelerateur_adjusts_budget_and_spends_the_power() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, tile)
	player.character = _char_with_power(&"coup_accelerateur")
	var phase := GamePhase.new([player] as Array[Player], board)
	phase.begin_movement(3)
	assert_true(phase.apply_reroll(2), "rerolled a 2-higher die")
	assert_eq(phase.movement().remaining(), 5)
	assert_false(phase.apply_reroll(1), "one-shot")


func test_passage_secret_makes_water_walkable_this_turn() -> void:
	var board := Board.new()
	var b := BlockDefinition.new()
	b.id = &"water_tile"
	b.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.WATER]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	board.place(b, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, b)
	player.character = _char_with_power(&"passage_secret")
	var phase := GamePhase.new([player] as Array[Player], board)
	phase.begin_movement(3)
	phase.try_step(Vector2i(1, 0))
	assert_false(phase.movement().legal_moves().has(Vector2i(2, 0)), "water blocked before the power")
	assert_true(phase.use_power())
	assert_true(phase.movement().legal_moves().has(Vector2i(2, 0)), "water passable after Passage Secret")


func test_bouclier_vert_cancels_the_next_malus() -> void:
	var phase := _phase_with_event()
	phase.begin_movement(3)
	phase.current_player().shield_charged = true
	var malus := EventCardDefinition.new()
	malus.effect = EventCardDefinition.Effect.MALUS_CASES
	malus.amount = 2
	malus.is_malus = true
	phase.apply_event(malus)
	assert_eq(phase.movement().remaining(), 3, "the malus was cancelled by the shield")
	assert_false(phase.current_player().shield_charged, "the shield is spent")
	assert_true(phase.context().shield_consumed)


func test_habitue_quartier_scores_a_delivery_as_full() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.BLUE)  # not the player's colour
	var player := _player(0, PlayerColor.Kind.RED, tile)
	player.character = _char_with_power(&"habitue_quartier")
	player.regular_route_charge = true
	var piece: PlacedPiece = board.pieces()[0]
	var delivery := Delivery.new(Vector2i(1, 0), Vector2i(2, 0), [piece] as Array[PlacedPiece])
	delivery.destinataire = DestinataireDefinition.new()
	var phase := GamePhase.new([player] as Array[Player], board, [delivery] as Array[Delivery])
	phase.begin_movement(3)
	phase.reserve_delivery()
	watch_signals(phase)
	phase.try_step(Vector2i(1, 0))  # drive -> EN_COURS
	phase.try_step(Vector2i(2, 0))  # recipient -> delivered
	assert_signal_emitted_with_parameters(phase, "delivery_completed", [delivery, ScoreCalculator.full_score()])
	assert_false(player.regular_route_charge, "the charge is spent")


func test_chargement_pro_grants_a_third_in_flight_slot() -> void:
	# With three deliveries on the start tile, the cap of 2 blocks the third — unless Margot's +1 applies.
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.RED)
	var player := _player(0, PlayerColor.Kind.RED, tile)
	player.character = _char_with_power(&"chargement_pro")
	var piece: PlacedPiece = board.pieces()[0]
	var deliveries: Array[Delivery] = []
	# Drive/recipient cells sit off the pawn's start, so reserving keeps them RESERVE (no auto pickup).
	for i in 3:
		var d := Delivery.new(Vector2i(10 + i, 0), Vector2i(20 + i, 0), [piece] as Array[PlacedPiece])
		d.destinataire = DestinataireDefinition.new()
		deliveries.append(d)
	var phase := GamePhase.new([player] as Array[Player], board, deliveries)
	phase.begin_movement(1)
	assert_true(phase.reserve_delivery(), "1st reserved")
	assert_true(phase.reserve_delivery(), "2nd reserved")
	assert_false(phase.reserve_delivery(), "3rd blocked at the default cap of 2")
	player.bonus_capacity = 1  # Margot's Chargement Pro
	assert_true(phase.reserve_delivery(), "3rd reservable with +1 capacity")
