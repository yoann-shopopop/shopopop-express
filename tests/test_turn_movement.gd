extends GutTest
## Tests for TurnMovement — the real board walk: revisiting allowed, adjustable budget,
## teleport. Diverges from Movement (which is self-avoiding and fixed-budget).


# A straight line of three walkable cells, plus an isolated one for stuck tests.
func _line() -> Dictionary:
	return {Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(2, 0): true}


func test_steps_onto_a_walkable_neighbor() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 2)
	assert_true(m.step(Vector2i(1, 0)))
	assert_eq(m.current(), Vector2i(1, 0))
	assert_eq(m.remaining(), 1)


func test_revisiting_a_cell_is_allowed() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 3)
	m.step(Vector2i(1, 0))
	assert_true(m.step(Vector2i(0, 0)), "backtracking onto the start is allowed")
	assert_eq(m.current(), Vector2i(0, 0))


func test_step_rejects_a_non_walkable_or_non_adjacent_cell() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 2)
	assert_false(m.step(Vector2i(5, 5)), "not walkable")
	assert_false(m.step(Vector2i(2, 0)), "walkable but not adjacent")


func test_add_steps_increases_the_budget() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 1)
	m.add_steps(2)
	assert_eq(m.remaining(), 3)


func test_subtract_steps_decreases_and_clamps_at_zero() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 1)
	m.subtract_steps(5)
	assert_eq(m.remaining(), 0)


func test_teleport_repositions_without_spending_budget() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 2)
	m.teleport_to(Vector2i(9, 9))  # an arbitrary, non-walkable cell (e.g. a drive)
	assert_eq(m.current(), Vector2i(9, 9))
	assert_eq(m.remaining(), 2, "teleport costs no budget")


func test_is_complete_when_budget_is_spent() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 1)
	m.step(Vector2i(1, 0))
	assert_true(m.is_complete())
	assert_true(m.is_finished())


func test_is_stuck_on_an_isolated_cell() -> void:
	var m := TurnMovement.new({Vector2i(0, 0): true}, Vector2i(0, 0), 2)
	assert_true(m.is_stuck())
	assert_true(m.is_finished())


func test_emits_step_budget_changed_on_step() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 2)
	watch_signals(m)
	m.step(Vector2i(1, 0))
	assert_signal_emitted_with_parameters(m, "step_budget_changed", [1])
