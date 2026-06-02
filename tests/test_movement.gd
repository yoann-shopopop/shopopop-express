extends GutTest
## Tests for Movement — a self-avoiding walk of fixed length over an injected set of walkable cells.
## No Board, no Pawn: the walkable set and adjacency (HexUtils) are all it needs.

const ORIGIN := Vector2i.ZERO
const N0 := Vector2i(1, 0)  # HexUtils.DIRECTIONS[0], adjacent to ORIGIN


func _cell_set(cells: Array) -> Dictionary:
	var d := {}
	for c in cells:
		d[c] = true
	return d


func _disk(side: int) -> Dictionary:
	return _cell_set(BlockDefinition.make_hexagon_cells(side))


func _corridor() -> Dictionary:
	return _cell_set([ORIGIN, N0])  # a dead-end of two cells


func test_starts_at_start_cell() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 4)
	assert_eq(m.current(), ORIGIN)
	assert_eq(m.remaining(), 4)
	assert_eq(m.path(), [ORIGIN] as Array[Vector2i])


func test_legal_moves_are_walkable_unvisited_neighbors() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 3)
	var moves := m.legal_moves()
	assert_eq(moves.size(), 6, "all six neighbors are walkable in a side-3 disk")
	for n in HexUtils.neighbors(ORIGIN):
		assert_true(moves.has(n))


func test_legal_moves_exclude_non_walkable_cells() -> void:
	var m := Movement.new(_corridor(), ORIGIN, 3)
	var moves := m.legal_moves()
	assert_eq(moves.size(), 1)
	assert_true(moves.has(N0))


func test_step_advances_and_decrements() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 3)
	assert_true(m.step(N0))
	assert_eq(m.current(), N0)
	assert_eq(m.remaining(), 2)
	assert_eq(m.path(), [ORIGIN, N0] as Array[Vector2i])


func test_step_emits_moved_signal() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 3)
	watch_signals(m)
	m.step(N0)
	assert_signal_emitted_with_parameters(m, "moved", [N0])


func test_illegal_step_is_rejected() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 3)
	assert_false(m.step(Vector2i(5, 5)), "not an adjacent walkable cell")
	assert_eq(m.current(), ORIGIN)
	assert_eq(m.remaining(), 3)


func test_cannot_revisit_a_walked_cell_including_start() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 5)
	m.step(N0)
	assert_false(m.legal_moves().has(ORIGIN), "the start cell is already visited")
	assert_false(m.step(ORIGIN), "stepping back onto a visited cell is illegal")


func test_exhausted_budget_completes_and_offers_no_moves() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 1)
	m.step(N0)
	assert_true(m.is_complete())
	assert_true(m.is_finished())
	assert_eq(m.legal_moves().size(), 0, "no moves once the budget is spent")


func test_dead_end_makes_movement_stuck_with_budget_left() -> void:
	var m := Movement.new(_corridor(), ORIGIN, 3)
	m.step(N0)
	assert_true(m.is_stuck())
	assert_true(m.is_finished())
	assert_false(m.is_complete())
	assert_eq(m.remaining(), 2, "leftover budget is lost on a forced stop")


func test_finished_signal_on_completion() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 1)
	watch_signals(m)
	m.step(N0)
	assert_signal_emitted(m, "finished")


func test_finished_signal_on_dead_end() -> void:
	var m := Movement.new(_corridor(), ORIGIN, 3)
	watch_signals(m)
	m.step(N0)
	assert_signal_emitted(m, "finished")


func test_zero_budget_is_complete_immediately() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 0)
	assert_true(m.is_complete())
	assert_true(m.is_finished())
	assert_eq(m.legal_moves().size(), 0)


func test_path_records_the_full_route() -> void:
	var m := Movement.new(_disk(3), ORIGIN, 2)
	m.step(N0)
	m.step(Vector2i(1, 1))  # neighbor of N0, unvisited, inside the disk
	assert_eq(m.path(), [ORIGIN, N0, Vector2i(1, 1)] as Array[Vector2i])
