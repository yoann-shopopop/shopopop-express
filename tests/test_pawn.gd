extends GutTest
## Tests for Pawn — pure runtime state (position + steps). No Board, no rendering.


func _mobile() -> PawnDefinition:
	var d := PawnDefinition.new()
	d.type = PawnDefinition.PawnType.COTRANSPORTER
	return d


func _fixed() -> PawnDefinition:
	var d := PawnDefinition.new()
	d.type = PawnDefinition.PawnType.DRIVE
	return d


func test_new_pawn_is_not_placed() -> void:
	assert_false(Pawn.new(_mobile()).is_placed)


func test_new_pawn_has_zero_steps() -> void:
	assert_eq(Pawn.new(_mobile()).steps, 0)


func test_place_marks_pawn_placed_at_cell() -> void:
	var p := Pawn.new(_fixed())
	assert_true(p.place(Vector2i(2, -1)), "first placement succeeds")
	assert_true(p.is_placed)
	assert_eq(p.position, Vector2i(2, -1))


func test_place_emits_placed_signal() -> void:
	var p := Pawn.new(_fixed())
	watch_signals(p)
	p.place(Vector2i(1, 1))
	assert_signal_emitted_with_parameters(p, "placed", [Vector2i(1, 1)])


func test_placing_twice_is_rejected() -> void:
	var p := Pawn.new(_fixed())
	p.place(Vector2i(0, 0))
	assert_false(p.place(Vector2i(5, 5)), "a pawn is placed only once")
	assert_eq(p.position, Vector2i(0, 0), "position is unchanged")


func test_mobile_pawn_moves_after_placement() -> void:
	var p := Pawn.new(_mobile())
	p.place(Vector2i(0, 0))
	assert_true(p.move_to(Vector2i(1, 0)))
	assert_eq(p.position, Vector2i(1, 0))


func test_move_emits_moved_signal_with_from_and_to() -> void:
	var p := Pawn.new(_mobile())
	p.place(Vector2i(0, 0))
	watch_signals(p)
	p.move_to(Vector2i(0, 1))
	assert_signal_emitted_with_parameters(p, "moved", [Vector2i(0, 0), Vector2i(0, 1)])


func test_move_before_placement_is_rejected() -> void:
	var p := Pawn.new(_mobile())
	assert_false(p.move_to(Vector2i(1, 0)), "cannot move an unplaced pawn")


func test_fixed_pawn_cannot_move() -> void:
	var p := Pawn.new(_fixed())
	p.place(Vector2i(0, 0))
	assert_false(p.move_to(Vector2i(1, 0)), "a fixed pawn never moves")
	assert_eq(p.position, Vector2i(0, 0))


func test_can_move_true_only_when_placed_and_mobile() -> void:
	var mobile := Pawn.new(_mobile())
	assert_false(mobile.can_move(), "not placed yet")
	mobile.place(Vector2i(0, 0))
	assert_true(mobile.can_move())
	var fixed := Pawn.new(_fixed())
	fixed.place(Vector2i(0, 0))
	assert_false(fixed.can_move(), "fixed pawns can never move")


func test_set_steps_updates_value() -> void:
	var p := Pawn.new(_mobile())
	assert_true(p.set_steps(4))
	assert_eq(p.steps, 4)


func test_set_steps_emits_signal() -> void:
	var p := Pawn.new(_mobile())
	watch_signals(p)
	p.set_steps(3)
	assert_signal_emitted_with_parameters(p, "steps_changed", [3])


func test_negative_steps_rejected() -> void:
	var p := Pawn.new(_mobile())
	p.set_steps(2)
	assert_false(p.set_steps(-1))
	assert_eq(p.steps, 2, "value unchanged on rejection")


func test_set_steps_rejected_for_fixed_pawn() -> void:
	var p := Pawn.new(_fixed())
	assert_false(p.set_steps(3), "a fixed pawn has no steps to travel")
	assert_eq(p.steps, 0)


func test_pawn_does_not_validate_board_topology() -> void:
	# With no Board, any cell is accepted for a placed mobile pawn — proves abstraction.
	var p := Pawn.new(_mobile())
	p.place(Vector2i(0, 0))
	assert_true(p.move_to(Vector2i(999, -999)))
	assert_eq(p.position, Vector2i(999, -999))
