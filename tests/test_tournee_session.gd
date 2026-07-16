extends GutTest
## Tests for TourneeSession — round/clock tracking, the chaining bonus, tiers, and the ghost score.


func test_clock_text_spans_8h_to_19h15_over_16_rounds() -> void:
	# 12h spread over 16 rounds = 45 min/round; round 16 is the last round to START, not "after" it.
	var board := Board.new()
	var tile := BlockDefinition.new()
	tile.id = &"t"
	tile.cells = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	tile.cell_types = [CellType.Kind.GREEN, CellType.Kind.ROUTE]
	tile.connectors = []
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.BLUE)
	var player := Player.new(PlayerColor.Kind.BLUE)
	player.start_block = tile
	var phase := GamePhase.new([player] as Array[Player], board)
	var session := TourneeSession.new()
	add_child_autofree(session)
	session.start(phase, 0)
	assert_eq(session.clock_text(), "8h00")
	assert_eq(session.rounds_left(), 16)

	for _round in 15:  # advance to round 16 (the 15th end_turn wraps round 1 -> 16)
		phase.begin_movement(1)
		phase.end_turn()
	assert_eq(session.current_round(), 16)
	assert_eq(session.clock_text(), "19h15")
	assert_eq(session.rounds_left(), 1)


func test_tier_for_matches_the_calibrated_thresholds() -> void:
	assert_eq(TourneeSession.tier_for(0), "")
	assert_eq(TourneeSession.tier_for(149), "")
	assert_eq(TourneeSession.tier_for(150), "Bronze")
	assert_eq(TourneeSession.tier_for(224), "Bronze")
	assert_eq(TourneeSession.tier_for(225), "Argent")
	assert_eq(TourneeSession.tier_for(299), "Argent")
	assert_eq(TourneeSession.tier_for(300), "Or")


# A start cell with two SEPARATE mono-tile deliveries branching off it in opposite directions —
# both completable within one generous turn budget, for the chaining-bonus test below.
func _two_deliveries_setup() -> Dictionary:
	var board := Board.new()
	var tile := BlockDefinition.new()
	tile.id = &"t"
	tile.cells = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(-3, 0),
	] as Array[Vector2i]
	tile.cell_types = [
		CellType.Kind.ROUTE, CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN,
		CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN,
	]
	tile.connectors = []
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.BLUE)
	var piece: PlacedPiece = board.pieces()[0]
	var d1 := Delivery.new(Vector2i(2, 0), Vector2i(3, 0), [piece] as Array[PlacedPiece])
	d1.destinataire = DestinataireDefinition.new()
	var d2 := Delivery.new(Vector2i(-2, 0), Vector2i(-3, 0), [piece] as Array[PlacedPiece])
	d2.destinataire = DestinataireDefinition.new()
	var player := Player.new(PlayerColor.Kind.BLUE)
	player.start_block = tile
	var phase := GamePhase.new([player] as Array[Player], board, [d1, d2] as Array[Delivery])
	return {"phase": phase, "player": player}


func test_chain_bonus_awarded_once_when_two_deliveries_complete_the_same_round() -> void:
	var ctx := _two_deliveries_setup()
	var phase: GamePhase = ctx["phase"]
	var session := TourneeSession.new()
	add_child_autofree(session)
	session.start(phase, 0)

	phase.begin_movement(9)
	phase.reserve_delivery()
	phase.try_step(Vector2i(1, 0))
	phase.try_step(Vector2i(2, 0))
	phase.try_step(Vector2i(3, 0))  # delivery 1 completed — no bonus yet (only 1 this round)
	assert_eq(session.chain_bonus_total(), 0)

	phase.try_step(Vector2i(2, 0))
	phase.try_step(Vector2i(1, 0))
	phase.try_step(Vector2i(0, 0))
	phase.reserve_delivery()
	phase.try_step(Vector2i(-1, 0))
	phase.try_step(Vector2i(-2, 0))
	phase.try_step(Vector2i(-3, 0))  # delivery 2 completed — same round: chain bonus!
	assert_eq(session.chain_bonus_total(), TourneeSession.CHAIN_BONUS)
	assert_eq(session.total_score(), phase.score_of(ctx["player"]) + TourneeSession.CHAIN_BONUS)


func test_no_chain_bonus_across_different_rounds() -> void:
	var ctx := _two_deliveries_setup()
	var phase: GamePhase = ctx["phase"]
	var session := TourneeSession.new()
	add_child_autofree(session)
	session.start(phase, 0)

	phase.begin_movement(3)
	phase.reserve_delivery()
	phase.try_step(Vector2i(1, 0))
	phase.try_step(Vector2i(2, 0))
	phase.try_step(Vector2i(3, 0))  # delivery 1, round 1
	phase.end_turn()

	phase.begin_movement(9)
	phase.try_step(Vector2i(2, 0))
	phase.try_step(Vector2i(1, 0))
	phase.try_step(Vector2i(0, 0))
	phase.reserve_delivery()
	phase.try_step(Vector2i(-1, 0))
	phase.try_step(Vector2i(-2, 0))
	phase.try_step(Vector2i(-3, 0))  # delivery 2, round 2 — no chaining across rounds
	assert_eq(session.chain_bonus_total(), 0)


func test_session_finishes_and_reports_a_result_when_all_deliveries_are_done() -> void:
	var ctx := _two_deliveries_setup()
	var phase: GamePhase = ctx["phase"]
	var session := TourneeSession.new()
	add_child_autofree(session)
	session.start(phase, 42)
	watch_signals(session)

	phase.begin_movement(9)
	phase.reserve_delivery()
	phase.try_step(Vector2i(1, 0))
	phase.try_step(Vector2i(2, 0))
	phase.try_step(Vector2i(3, 0))
	phase.try_step(Vector2i(2, 0))
	phase.try_step(Vector2i(1, 0))
	phase.try_step(Vector2i(0, 0))
	phase.reserve_delivery()
	phase.try_step(Vector2i(-1, 0))
	phase.try_step(Vector2i(-2, 0))
	phase.try_step(Vector2i(-3, 0))  # both deliveries done: is_finished() -> session ends

	assert_signal_emitted(session, "session_finished")
	var params: Array = get_signal_parameters(session, "session_finished")
	var result: Dictionary = params[0]
	assert_eq(result["chain_bonus"], TourneeSession.CHAIN_BONUS)
	assert_eq(result["ghost_score"], 42)
	assert_eq(result["score"], phase.score_of(ctx["player"]) + TourneeSession.CHAIN_BONUS)


func test_session_finishes_after_16_rounds_even_with_deliveries_left() -> void:
	var board := Board.new()
	var tile := BlockDefinition.new()
	tile.id = &"t"
	tile.cells = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	tile.cell_types = [CellType.Kind.GREEN, CellType.Kind.ROUTE]
	tile.connectors = []
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.BLUE)
	var player := Player.new(PlayerColor.Kind.BLUE)
	player.start_block = tile
	var piece: PlacedPiece = board.pieces()[0]
	var never_reached := Delivery.new(Vector2i(50, 50), Vector2i(50, 51), [piece] as Array[PlacedPiece])
	never_reached.destinataire = DestinataireDefinition.new()
	var phase := GamePhase.new([player] as Array[Player], board, [never_reached] as Array[Delivery])
	var session := TourneeSession.new()
	add_child_autofree(session)
	session.start(phase, 0)
	watch_signals(session)

	for _round in TourneeSession.MAX_ROUNDS:
		phase.begin_movement(1)
		phase.end_turn()

	assert_signal_emitted(session, "session_finished")


func test_compute_ghost_score_is_deterministic_for_the_same_seed() -> void:
	var board := Board.new()
	var tile := BlockDefinition.new()
	tile.id = &"t"
	tile.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i]
	tile.cell_types = [
		CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN,
	]
	tile.connectors = []
	board.place(tile, Vector2i.ZERO, 0, PlayerColor.Kind.BLUE)
	var piece: PlacedPiece = board.pieces()[0]
	var player := Player.new(PlayerColor.Kind.BLUE)
	player.start_block = tile
	var enseigne := EnseigneDefinition.new()
	var destinataire := DestinataireDefinition.new()
	destinataire.id = &"d0"
	var delivery := Delivery.new(Vector2i(2, 0), Vector2i(3, 0), [piece] as Array[PlacedPiece])
	delivery.enseigne = enseigne
	delivery.destinataire = destinataire
	var more_destinataires: Array[DestinataireDefinition] = [destinataire]
	var enseignes: Array[EnseigneDefinition] = [enseigne]
	var events: Array[CardDefinition] = []

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 7
	var score_a := TourneeSession.compute_ghost_score(
		board, player, [delivery] as Array[Delivery], enseignes, more_destinataires, events, rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 7
	var score_b := TourneeSession.compute_ghost_score(
		board, player, [delivery] as Array[Delivery], enseignes, more_destinataires, events, rng_b)

	assert_eq(score_a, score_b)
	assert_gt(score_a, 0, "the one mono-tile delivery should be completed by the greedy bot")
