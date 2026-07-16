extends GutTest
## Tests for TutorialScenario — the hand-authored, deterministic mini-board for the tutorial.


func test_board_places_one_tile_owned_by_the_given_color() -> void:
	var board := TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	assert_eq(board.pieces().size(), 1)
	assert_eq(board.pieces()[0].owner, PlayerColor.Kind.BLUE)


func test_cells_form_a_straight_walkable_line_with_one_event_in_the_middle() -> void:
	var board := TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	assert_eq(board.cell_type_at(TutorialScenario.START_CELL), CellType.Kind.GREEN)
	assert_eq(board.cell_type_at(TutorialScenario.EVENT_CELL), CellType.Kind.EVENT)
	assert_eq(board.cell_type_at(TutorialScenario.DRIVE_CELL), CellType.Kind.URBAN)
	assert_eq(board.cell_type_at(TutorialScenario.RECIPIENT_CELL), CellType.Kind.GREEN)


func test_player_starts_on_the_tile_at_the_start_cell() -> void:
	var board := TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	var player := TutorialScenario.build_player(PlayerColor.Kind.BLUE, board)
	assert_eq(player.index, 0)
	assert_eq(player.start_cell, TutorialScenario.START_CELL)
	assert_same(player.start_block, board.pieces()[0].block_def)


func test_delivery_spans_the_drive_and_recipient_cells_and_has_a_recipient() -> void:
	var board := TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	var delivery := TutorialScenario.build_delivery(board)
	assert_eq(delivery.drive_cell, TutorialScenario.DRIVE_CELL)
	assert_eq(delivery.recipient_cell, TutorialScenario.RECIPIENT_CELL)
	assert_not_null(delivery.destinataire, "is_reservable() requires a non-null recipient")
	assert_true(delivery.is_single_tile(), "mono-tile: both bonuses apply once delivered")


func test_delivery_scores_the_full_25_for_the_owning_color() -> void:
	var board := TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	var delivery := TutorialScenario.build_delivery(board)
	assert_eq(ScoreCalculator.score_delivery(delivery, PlayerColor.Kind.BLUE), 25)


func test_event_order_offers_one_avantage_and_one_malus() -> void:
	var order := TutorialScenario.build_event_order()
	assert_eq(order.size(), 2)
	var e0: EventCardDefinition = order[0]
	var e1: EventCardDefinition = order[1]
	assert_false(e0.is_malus, "Grand Soleil is a safe Avantage")
	assert_true(e1.is_malus, "Recharge de Batterie: a real choice between the two")
