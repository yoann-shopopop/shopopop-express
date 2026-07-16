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


# --- path_to (the multi-cell click-to-walk / hover-preview BFS) -------------

func test_path_to_an_adjacent_cell_is_a_single_step() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 5)
	assert_eq(m.path_to(Vector2i(1, 0)), [Vector2i(1, 0)])


func test_path_to_a_farther_cell_lists_every_intermediate_step() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 5)
	assert_eq(m.path_to(Vector2i(2, 0)), [Vector2i(1, 0), Vector2i(2, 0)])


func test_path_to_the_current_cell_is_empty() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 5)
	assert_eq(m.path_to(Vector2i(0, 0)), [])


func test_path_to_an_unreachable_cell_is_empty() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 5)
	assert_eq(m.path_to(Vector2i(9, 9)), [])


func test_path_to_updates_from_the_current_position_after_stepping() -> void:
	var m := TurnMovement.new(_line(), Vector2i(0, 0), 5)
	m.step(Vector2i(1, 0))
	assert_eq(m.path_to(Vector2i(2, 0)), [Vector2i(2, 0)], "path is relative to current(), not the start")


func test_path_to_finds_the_shortest_route_when_a_longer_detour_also_exists() -> void:
	# Direct: (0,0)->(1,0)->(2,0), 2 steps. Detour: (0,0)->(0,1)->(1,1)->(2,1)->(2,0), 4 steps.
	# Both reach (2,0); BFS must return the 2-step direct route.
	var walkable := {
		Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(2, 0): true,
		Vector2i(0, 1): true, Vector2i(1, 1): true, Vector2i(2, 1): true,
	}
	var m := TurnMovement.new(walkable, Vector2i(0, 0), 5)
	assert_eq(m.path_to(Vector2i(2, 0)), [Vector2i(1, 0), Vector2i(2, 0)])
