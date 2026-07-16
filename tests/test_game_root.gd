extends GutTest
## Integration smoke test for GameRoot: setting it up wires dice/pawns/deliveries/UI/controller without
## error and spawns one pawn view per player. The tile carries a GREEN + URBAN so a delivery (fed by the
## DeliveryGenerator) is built, exercising the enseigne/destinataire markers too. Runs in GUT's SceneTree.


func _tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"start_tile"
	# GREEN (start, excluded from recipients), ROUTE, URBAN (drive), GREEN (recipient, road-adjacent).
	b.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, -1)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	return b


func _player(index: int, color: int, start_block: BlockDefinition) -> Player:
	var p := Player.new(color)
	p.index = index
	p.start_block = start_block
	p.start_cell = Vector2i(0, 0)
	return p


func _setup_root() -> GameRoot:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var players: Array[Player] = [
		_player(0, PlayerColor.Kind.BLUE, tile),
		_player(1, PlayerColor.Kind.RED, tile),
	]
	var camera := Camera3D.new()
	add_child_autofree(camera)

	var root := GameRoot.new()
	add_child_autofree(root)
	root.setup(board, players, camera)
	return root


func test_setup_spawns_one_pawn_view_per_player_without_error() -> void:
	var root := _setup_root()

	var pawn_views := 0
	for child in root.get_children():
		if child is PawnView:
			pawn_views += 1
	# 2 cotransporter pawns (one per player) + 2 tokens per delivery (drive + recipient).
	# The test tile has 1 deliverable pair (URBAN drive + GREEN recipient) → 2 + 2 = 4.
	assert_eq(pawn_views, 4, "2 pawn views per player + 2 token views per delivery")


func test_hovering_a_delivery_highlights_its_cells_and_link() -> void:
	var root := _setup_root()
	assert_eq(root._hover_markers.get_child_count(), 0, "no hover markers before any hover")
	var delivery := root.deliveries()[0]  # drive (2,0) / recipient (1,-1): two different cells
	root._on_delivery_hovered(delivery)
	# 2 cell rings + 1 link bar (cells differ).
	assert_eq(root._hover_markers.get_child_count(), 3)
	root._on_delivery_unhovered(delivery)
	assert_eq(root._hover_markers.get_child_count(), 0, "unhovering the same delivery clears the markers")


func test_a_stale_unhover_does_not_clear_a_newer_hover() -> void:
	var root := _setup_root()
	var delivery := root.deliveries()[0]
	var other := Delivery.new(Vector2i(9, 9), Vector2i(9, 9), [] as Array[PlacedPiece])
	root._on_delivery_hovered(other)   # the mouse left the old card...
	root._on_delivery_hovered(delivery)  # ...and entered a new one before the old exit signal arrived
	root._on_delivery_unhovered(other)  # the stale exit from the FIRST card must not wipe the new hover
	assert_gt(root._hover_markers.get_child_count(), 0, "the newer hover's markers must survive")


# A straight 4-cell road, for the click-to-walk tests below (no delivery on it — irrelevant here).
func _long_road_root() -> GameRoot:
	var board := Board.new()
	var tile := BlockDefinition.new()
	tile.id = &"long_road"
	tile.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i]
	tile.cell_types = [
		CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.ROUTE, CellType.Kind.ROUTE,
	]
	tile.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	board.place(tile, Vector2i.ZERO, 0, 0)
	var players: Array[Player] = [_player(0, PlayerColor.Kind.BLUE, tile)]
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var root := GameRoot.new()
	add_child_autofree(root)
	root.setup(board, players, camera)
	return root


func test_hovering_a_far_cell_previews_the_full_path_and_its_cost() -> void:
	var root := _long_road_root()
	root.phase().begin_movement(3)
	root._on_cell_hovered(Vector2i(2, 0))  # 2 steps away, affordable within a 3-step budget
	# 2 path-cell markers + 1 cost label.
	assert_eq(root._path_preview.get_child_count(), 3)
	root._on_hover_cleared()
	assert_eq(root._path_preview.get_child_count(), 0)


func test_hovering_a_cell_farther_than_the_budget_still_previews_it() -> void:
	var root := _long_road_root()
	root.phase().begin_movement(1)  # only 1 step, but (3,0) is 3 away
	root._on_cell_hovered(Vector2i(3, 0))
	assert_eq(root._path_preview.get_child_count(), 4, "3 path markers + the cost label, even if unaffordable")


func test_clicking_a_far_cell_auto_walks_the_full_bfs_path() -> void:
	var root := _long_road_root()
	root.phase().begin_movement(3)
	root._on_cell_clicked(Vector2i(3, 0))
	assert_true(root._walking, "the walk starts synchronously on click")
	await wait_seconds(1.0)  # 3 steps, 2 inter-step delays of 0.2s — comfortably finished by then
	assert_eq(
		root.phase().position_of(root.phase().current_player()), Vector2i(3, 0), "walked the full path")
	assert_eq(root.phase().movement().remaining(), 0)
	assert_false(root._walking, "the walk flag clears once the path is exhausted")


func test_a_click_is_ignored_while_a_walk_is_already_in_progress() -> void:
	var root := _long_road_root()
	root.phase().begin_movement(3)
	root._on_cell_clicked(Vector2i(3, 0))
	root._on_cell_clicked(Vector2i(1, 0))  # fired while the first walk is still animating: must be dropped
	await wait_seconds(1.0)
	assert_eq(
		root.phase().position_of(root.phase().current_player()), Vector2i(3, 0),
		"the second click didn't derail the first walk")


# --- Auto-offered reservation (the prompt on arrival, not just the manual button) --------------

func test_maybe_prompt_reservation_offers_once_then_stays_silent_this_turn() -> void:
	var root := _setup_root()
	root.phase().begin_movement(2)
	# The fixture tile is a single piece (GREEN/ROUTE/URBAN/GREEN): stepping onto ANY of its cells
	# already sits on the drive's tile, so the built-in delivery is reservable from the first step.
	root.phase().try_step(Vector2i(1, 0))
	assert_true(root._maybe_prompt_reservation(), "first arrival on the tile: offers the prompt")
	root.hud().dismiss_chooser()
	assert_false(root._maybe_prompt_reservation(), "already asked this turn: no second prompt")


func test_reservation_prompted_resets_on_a_new_turn() -> void:
	var root := _setup_root()
	root.phase().begin_movement(2)
	root.phase().try_step(Vector2i(1, 0))
	root._maybe_prompt_reservation()
	root.hud().dismiss_chooser()
	root._on_turn_changed(root.phase().current_player())  # simulates the turn-boundary reset
	assert_false(root._reservation_prompted.has(root.phase().reservable_delivery()))


func test_auto_walk_pauses_for_the_reservation_prompt_then_resumes_on_choice() -> void:
	var root := _setup_root()
	root.phase().begin_movement(2)
	root._on_cell_clicked(Vector2i(2, 0))  # the built-in delivery's drive cell, 2 steps from the start
	assert_true(root._walking, "paused mid-walk, waiting on the reservation prompt")
	var hud: PlayHud = root.hud()
	assert_not_null(hud._chooser, "the reservation prompt is showing")
	# Press the (only) "Réserver" option button, deep in show_chooser's built tree.
	var reserve_button: Button = hud._chooser.get_child(0).get_child(0).get_child(0).get_child(1).get_child(0)
	reserve_button.pressed.emit()
	await wait_seconds(0.4)  # resumes after the inter-step delay and finishes the remaining step
	assert_false(root._walking, "the walk resumed and completed")
	assert_null(root.phase().reservable_delivery(), "reserved: no longer offerable")
	assert_eq(
		root.phase().position_of(root.phase().current_player()), Vector2i(2, 0), "walked the full path")


# --- Coup de pouce (boost tokens) --------------------------------------------

func test_boost_usable_right_after_rolling_not_after_a_step() -> void:
	var root := _setup_root()
	root._on_roll()
	assert_true(root._boost_usable_now())
	root.phase().try_step(Vector2i(1, 0))
	assert_false(root._boost_usable_now(), "already took a step")


func test_boost_requested_reroll_all_adjusts_budget_and_spends_a_token() -> void:
	var root := _setup_root()
	root._on_roll()
	var player := root.phase().current_player()
	var before_tokens := player.boost_tokens
	var before_remaining := root.phase().movement().remaining()
	var old_total := root._dice.total()
	root._on_boost_requested()
	var hud: PlayHud = root.hud()
	assert_not_null(hud._chooser, "the boost chooser is showing")
	var reroll_button: Button = hud._chooser.get_child(0).get_child(0).get_child(0).get_child(1).get_child(0)
	reroll_button.pressed.emit()
	var new_total := root._dice.total()
	assert_eq(player.boost_tokens, before_tokens - 1)
	assert_eq(root.phase().movement().remaining(), before_remaining + (new_total - old_total))


func test_boost_requested_fix_a_die_sets_it_to_max_and_adjusts_budget() -> void:
	var root := _setup_root()
	root._on_roll()  # default (no character): 2 dice
	var player := root.phase().current_player()
	var before_remaining := root.phase().movement().remaining()
	var old_value: int = root._dice.values()[0]
	root._on_boost_requested()
	var hud: PlayHud = root.hud()
	# options: [0] Relancer tout, [1] Dé 1 → max, [2] Dé 2 → max
	var fix_button: Button = hud._chooser.get_child(0).get_child(0).get_child(0).get_child(1).get_child(1)
	fix_button.pressed.emit()
	assert_eq(root._dice.values()[0], DiceRoller.SIDES)
	assert_eq(root.phase().movement().remaining(), before_remaining + (DiceRoller.SIDES - old_value))
	assert_eq(player.boost_tokens, 1)


func test_boost_requested_is_ignored_after_a_step_is_taken() -> void:
	var root := _setup_root()
	root._on_roll()
	root.phase().try_step(Vector2i(1, 0))
	var player := root.phase().current_player()
	var before_tokens := player.boost_tokens
	root._on_boost_requested()
	assert_null(root.hud()._chooser, "too late to offer the boost: no chooser opens")
	assert_eq(player.boost_tokens, before_tokens, "nothing spent")


# --- Solo vs IA (AutoPilot promoted to an in-game opponent) -----------------

# Same fixture tile as _setup_root() (1 deliverable pair, no EVENT cell — keeps AI-turn timing
# predictable: only dice randomness affects duration, never a REJOUER/event chain).
func _setup_root_with_ai(ai_flags: Array) -> GameRoot:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var colors := [PlayerColor.Kind.BLUE, PlayerColor.Kind.RED]
	var players: Array[Player] = []
	for i in ai_flags.size():
		var p := _player(i, colors[i], tile)
		p.is_ai = ai_flags[i]
		players.append(p)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var root := GameRoot.new()
	add_child_autofree(root)
	root.setup(board, players, camera)
	return root


# Polls until the AI has finished all its chained turns (bounded), rather than a fixed sleep: real
# dice are unseeded here (GameRoot has no RNG injection yet — that's task #22), so a worst-case-bad
# roll can make a fixed wait flaky. Godot's cooperative scheduling means a seat-to-seat handoff
# inside end_turn() never yields mid-transition, so a single poll loop safely spans multiple chained
# AI turns (replays, consecutive AI seats) without a race on the momentary "false" between them.
func _wait_until_ai_done(root: GameRoot, cap_seconds: float = 6.0) -> void:
	var elapsed := 0.0
	while elapsed < cap_seconds and root._ai_playing:
		await wait_seconds(0.25)
		elapsed += 0.25


func test_ai_seat_auto_plays_from_the_very_first_turn() -> void:
	var root := _setup_root_with_ai([true, false])
	assert_true(root._ai_playing, "kicks off at setup — turn_changed only fires from end_turn")
	await _wait_until_ai_done(root)
	assert_false(root._ai_playing, "the AI's turn has finished")
	assert_eq(root.phase().current_player().index, 1, "no EVENT cell in this fixture: never a replay")
	assert_eq(root.phase().current_subphase(), GamePhase.SubPhase.PLANIFICATION)


func test_ai_never_opens_the_interactive_event_card_modal() -> void:
	var root := _setup_root_with_ai([true, false])
	root._on_event_triggered(Vector2i(0, 0))
	assert_null(root._event_choice, "the human 3D card modal must never open for an AI-controlled seat")


func test_ai_reserves_silently_without_a_confirmation_chooser() -> void:
	var root := _setup_root_with_ai([true, false])
	await _wait_until_ai_done(root)
	assert_null(root.hud()._chooser, "no chooser was ever shown during the AI's turn")


func test_human_seat_is_unaffected_by_the_ai_wiring() -> void:
	var root := _setup_root_with_ai([false, false])
	assert_false(root._ai_playing, "no AI seat: nothing auto-plays")
	assert_true(root._can_roll, "the human must roll manually")


# A bare 4-cell road, no delivery at all: unlike _tile(), the game can never finish (is_finished()
# requires at least one delivery), so both AI seats keep genuinely cycling turns — the regression
# below isn't confounded by the (very likely, on the tiny _tile() fixture) game ending after seat 0's
# very first turn, which would make "seat 1 never played" indistinguishable from "game over already".
func _bare_road_root_with_ai(ai_flags: Array) -> GameRoot:
	var board := Board.new()
	var tile := BlockDefinition.new()
	tile.id = &"bare_road"
	tile.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i]
	tile.cell_types = [
		CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.ROUTE, CellType.Kind.ROUTE,
	]
	tile.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	board.place(tile, Vector2i.ZERO, 0, 0)
	var colors := [PlayerColor.Kind.BLUE, PlayerColor.Kind.RED]
	var players: Array[Player] = []
	for i in ai_flags.size():
		var p := _player(i, colors[i], tile)
		p.is_ai = ai_flags[i]
		players.append(p)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var root := GameRoot.new()
	add_child_autofree(root)
	root.setup(board, players, camera)
	return root


func test_both_ai_seats_play_in_sequence_without_external_input() -> void:
	# Regression guard for the _ai_playing/end_turn ordering: if _ai_playing were reset AFTER
	# end_turn() instead of before, the second AI seat's turn_changed (fired synchronously from
	# inside end_turn) would be swallowed by the still-true guard, and seat 1 would sit forever
	# unplayed in PLANIFICATION. This fixture has no delivery, so with both seats AI the game never
	# naturally goes idle (is_finished() needs at least one delivery) — that's fine, proving the fix
	# only needs ONE full round-robin cycle, not the AI ever pausing; hence polling round_number
	# and pawn positions here rather than _wait_until_ai_done/_ai_playing.
	var root := _bare_road_root_with_ai([true, true])
	var start_p0 := root.phase().position_of(root._players[0])
	var start_p1 := root.phase().position_of(root._players[1])
	var elapsed := 0.0
	while elapsed < 8.0 and root.phase().round_number() < 2:
		await wait_seconds(0.25)
		elapsed += 0.25
	assert_gte(root.phase().round_number(), 2, "both seats played: a new round began")
	assert_ne(root.phase().position_of(root._players[0]), start_p0, "seat 0 moved")
	assert_ne(root.phase().position_of(root._players[1]), start_p1, "seat 1 moved — the ordering fix works")


func test_ai_stops_auto_playing_once_the_game_is_finished() -> void:
	var root := _setup_root_with_ai([true, false])  # this fixture's 1 delivery is likely completed in 1 turn
	await _wait_until_ai_done(root)
	if not root.phase().is_finished():
		pending("this run's dice didn't finish the single delivery in one turn — inconclusive")
		return
	root._play_ai_turn(root._players[0])
	assert_false(root._ai_playing, "no-ops once the game has ended, even if called directly")


func test_declining_the_reservation_prompt_still_lets_the_walk_finish() -> void:
	var root := _setup_root()
	root.phase().begin_movement(2)
	root._on_cell_clicked(Vector2i(2, 0))
	var hud: PlayHud = root.hud()
	var cancel_button: Button = hud._chooser.get_child(0).get_child(0).get_child(0).get_child(2)
	cancel_button.pressed.emit()
	await wait_seconds(0.4)
	assert_false(root._walking)
	assert_not_null(root.phase().reservable_delivery(), "declined: still offerable via the manual button")
	assert_eq(root.phase().position_of(root.phase().current_player()), Vector2i(2, 0))


# --- Deterministic session overrides (setup's optional params — task #22, enables the tutorial) ---

func test_forced_deliveries_bypass_random_placement() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var piece: PlacedPiece = board.pieces()[0]
	var enseigne := EnseigneDefinition.new()
	enseigne.display_name = "Fournil d'Hector"
	var destinataire := DestinataireDefinition.new()
	destinataire.display_name = "Mamie Turbo"
	var forced := Delivery.new(Vector2i(2, 0), Vector2i(1, -1), [piece] as Array[PlacedPiece])
	forced.enseigne = enseigne
	forced.destinataire = destinataire
	var players: Array[Player] = [_player(0, PlayerColor.Kind.BLUE, tile)]
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var root := GameRoot.new()
	add_child_autofree(root)

	root.setup(board, players, camera, null, [forced] as Array[Delivery])

	assert_eq(root.deliveries().size(), 1)
	assert_same(root.deliveries()[0], forced, "the exact forced Delivery is used, not a random pick")
	assert_eq(root.deliveries()[0].enseigne.display_name, "Fournil d'Hector")


func test_forced_deliveries_have_no_recycling_generator() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var piece: PlacedPiece = board.pieces()[0]
	var forced := Delivery.new(Vector2i(2, 0), Vector2i(1, -1), [piece] as Array[PlacedPiece])
	forced.destinataire = DestinataireDefinition.new()
	var players: Array[Player] = [_player(0, PlayerColor.Kind.BLUE, tile)]
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var root := GameRoot.new()
	add_child_autofree(root)
	root.setup(board, players, camera, null, [forced] as Array[Delivery])

	root.phase().begin_movement(4)  # (0,0)->(1,0)->(2,0) pickup, back through (1,0)->(1,-1) deliver
	root.phase().reserve_delivery()
	root.phase().try_step(Vector2i(1, 0))
	root.phase().try_step(Vector2i(2, 0))
	root.phase().try_step(Vector2i(1, 0))
	root.phase().try_step(Vector2i(1, -1))  # completes the delivery
	assert_null(forced.destinataire, "no generator to recycle: the drive is simply left free")
	assert_true(root.phase().is_finished(), "a short scripted session still ends correctly")


func test_random_placement_caps_the_recipient_pool_at_the_tile_count_by_default() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var players: Array[Player] = [_player(0, PlayerColor.Kind.BLUE, tile)]
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var root := GameRoot.new()
	add_child_autofree(root)
	root.setup(board, players, camera)
	assert_eq(root.phase().generator().remaining_recipients(), 0,
		"1 tile -> 1 delivery -> the pool holds no extra identity beyond that cap")


## La Tournée's continuous 16-round recycling needs the identity pool NOT capped at the tile count
## (task #24) — the [param uncapped_deliveries] override on [method GameRoot.setup].
func test_uncapped_deliveries_leaves_extra_recipients_in_the_pool() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var players: Array[Player] = [_player(0, PlayerColor.Kind.BLUE, tile)]
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var root := GameRoot.new()
	add_child_autofree(root)
	root.setup(board, players, camera, null, [], null, [], true)
	assert_gt(root.phase().generator().remaining_recipients(), 0,
		"uncapped: destinataires beyond the tile count stay in the pool for later recycling")


func test_forced_dice_overrides_the_internal_dice_roller() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var players: Array[Player] = [_player(0, PlayerColor.Kind.BLUE, tile)]
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var root := GameRoot.new()
	add_child_autofree(root)
	var injected := DiceRoller.new(RandomNumberGenerator.new())
	root.setup(board, players, camera, null, [], injected)
	assert_same(root._dice, injected, "the injected DiceRoller instance is used, not a fresh one")


func test_forced_event_order_overrides_the_shuffle() -> void:
	var board := Board.new()
	var tile := BlockDefinition.new()
	tile.id = &"event_tile"
	tile.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i]
	tile.cell_types = [CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.EVENT]
	tile.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	board.place(tile, Vector2i.ZERO, 0, 0)
	var players: Array[Player] = [_player(0, PlayerColor.Kind.BLUE, tile)]
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var root := GameRoot.new()
	add_child_autofree(root)

	var first_card := EventCardDefinition.new()
	first_card.id = &"forced_first"
	first_card.display_name = "Carte forcée"
	first_card.effect = EventCardDefinition.Effect.BONUS_CASES
	first_card.amount = 3
	var second_card := EventCardDefinition.new()
	second_card.id = &"forced_second"
	var order: Array[CardDefinition] = [first_card, second_card]
	root.setup(board, players, camera, null, [], null, order)

	root.phase().begin_movement(3)
	root.phase().try_step(Vector2i(1, 0))
	root.phase().try_step(Vector2i(2, 0))  # the EVENT cell: draws 2 from the forced order
	assert_eq(root._events.draw_count(), 0, "both forced cards were drawn (draw(2) from a 2-card deck)")
