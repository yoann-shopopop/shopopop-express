extends GutTest
## Tests for TutorialDirector — the reactive beat sequencer, driven against a real GamePhase over
## TutorialScenario's mini-board (no mouse/GameRoot involved: it only needs GamePhase signals).


func _director(phase: GamePhase) -> Dictionary:
	var overlay := TutorialOverlay.new()
	add_child_autofree(overlay)
	var director := TutorialDirector.new()
	add_child_autofree(director)
	director.start(phase, overlay)
	return {"director": director, "overlay": overlay}


func test_opens_with_a_welcome_message() -> void:
	var board := TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	var player := TutorialScenario.build_player(PlayerColor.Kind.BLUE, board)
	var phase := GamePhase.new([player] as Array[Player], board, [TutorialScenario.build_delivery(board)] as Array[Delivery])
	var ctx := _director(phase)
	assert_string_contains(ctx["overlay"]._label.text, "Bienvenue")


func test_first_movement_prompts_the_survole_clique_beat() -> void:
	var board := TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	var player := TutorialScenario.build_player(PlayerColor.Kind.BLUE, board)
	var phase := GamePhase.new([player] as Array[Player], board, [TutorialScenario.build_delivery(board)] as Array[Delivery])
	var ctx := _director(phase)
	phase.begin_movement(5)
	assert_string_contains(ctx["overlay"]._label.text, "Survole")


func test_reservation_and_pickup_and_event_and_delivery_each_update_the_bubble() -> void:
	var board := TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	var player := TutorialScenario.build_player(PlayerColor.Kind.BLUE, board)
	var delivery := TutorialScenario.build_delivery(board)
	var phase := GamePhase.new([player] as Array[Player], board, [delivery] as Array[Delivery])
	var ctx := _director(phase)
	var overlay: TutorialOverlay = ctx["overlay"]

	phase.begin_movement(5)  # (0,0) start: the drive's tile is reservable right away
	phase.reserve_delivery()
	assert_string_contains(overlay._label.text, "réservée")

	phase.try_step(Vector2i(1, 0))
	phase.try_step(TutorialScenario.EVENT_CELL)
	assert_string_contains(overlay._label.text, "Case événement")

	var card := EventCardDefinition.new()
	card.effect = EventCardDefinition.Effect.BONUS_CASES
	card.amount = 3
	phase.apply_event(card)

	phase.try_step(Vector2i(3, 0))
	phase.try_step(TutorialScenario.DRIVE_CELL)
	assert_string_contains(overlay._label.text, "Chargé automatiquement")

	phase.try_step(TutorialScenario.RECIPIENT_CELL)
	assert_string_contains(overlay._label.text, "25 points")
	assert_true(overlay._finish_btn.visible, "the final beat shows the Terminer button")


func test_finish_button_press_emits_finished() -> void:
	var board := TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	var player := TutorialScenario.build_player(PlayerColor.Kind.BLUE, board)
	var phase := GamePhase.new([player] as Array[Player], board, [TutorialScenario.build_delivery(board)] as Array[Delivery])
	var ctx := _director(phase)
	watch_signals(ctx["director"])
	ctx["overlay"]._finish_btn.pressed.emit()
	assert_signal_emitted(ctx["director"], "finished")
