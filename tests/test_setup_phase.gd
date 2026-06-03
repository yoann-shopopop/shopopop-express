extends GutTest
## Tests for SetupPhase — turn model: each turn places exactly one block (which does NOT advance the
## turn), the placed block can be removed/rotated, the free bridge may also be placed, and
## "finish_turn" ends the turn. A player is done once no blocks remain; a leftover bridge is abandoned
## (a player never gets a turn with only a bridge to place).

var _board: Board
var _phase: SetupPhase


func _road_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	return b


# Two-cell horizontal road; both cells are connectors. Its footprint changes with rotation.
func _road2() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.cells = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE, CellType.Kind.ROUTE]
	b.connectors = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	return b


func _bridge() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.cells = BlockDefinition.make_line_cells(3)
	b.cell_types = [CellType.Kind.WATER, CellType.Kind.ROUTE, CellType.Kind.WATER]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]  # only the central road cell connects
	return b


func _player(color: int, piece_count: int) -> Player:
	var p := Player.new(color)
	for _i in piece_count:
		p.pieces.append(_road_tile())
	return p


func before_each() -> void:
	_board = Board.new()
	var players: Array[Player] = [
		_player(PlayerColor.Kind.BLUE, 2),
		_player(PlayerColor.Kind.RED, 2),
	]
	_phase = SetupPhase.new(players, _board)


func test_starts_with_the_first_player() -> void:
	assert_eq(_phase.current_player().color, PlayerColor.Kind.BLUE)


func test_placing_a_block_does_not_advance_the_turn() -> void:
	assert_true(_phase.try_place(0, Vector2i.ZERO, 0))
	assert_eq(_phase.current_player().color, PlayerColor.Kind.BLUE, "still the same player")
	assert_true(_phase.block_placed_this_turn())


func test_cannot_place_a_second_block_in_the_same_turn() -> void:
	_phase.try_place(0, Vector2i.ZERO, 0)
	assert_false(_phase.try_place(0, Vector2i(1, 0), 0), "only one block per turn")


func test_remove_block_returns_it_to_the_tray() -> void:
	_phase.try_place(0, Vector2i.ZERO, 0)
	assert_eq(_phase.current_player().pieces.size(), 1, "one block held while one is placed")
	assert_true(_phase.remove_block())
	assert_false(_phase.block_placed_this_turn())
	assert_eq(_phase.current_player().pieces.size(), 2, "block returned to the tray")
	assert_true(_board.is_empty())


func test_finish_turn_is_blocked_without_a_placed_block() -> void:
	assert_false(_phase.finish_turn())
	assert_eq(_phase.current_player().color, PlayerColor.Kind.BLUE)


func test_finish_turn_advances_after_a_block_is_placed() -> void:
	_phase.try_place(0, Vector2i.ZERO, 0)
	assert_true(_phase.finish_turn())
	assert_eq(_phase.current_player().color, PlayerColor.Kind.RED)
	assert_false(_phase.block_placed_this_turn(), "fresh turn has no placed block")


func test_round_robin_returns_to_the_first_player() -> void:
	_phase.try_place(0, Vector2i.ZERO, 0)
	_phase.finish_turn()                               # BLUE
	_phase.try_place(0, Vector2i(1, 0), 0)
	_phase.finish_turn()                               # RED
	assert_eq(_phase.current_player().color, PlayerColor.Kind.BLUE)


func test_phase_finishes_when_all_blocks_are_placed() -> void:
	watch_signals(_phase)
	_phase.try_place(0, Vector2i.ZERO, 0); _phase.finish_turn()    # BLUE 1
	_phase.try_place(0, Vector2i(1, 0), 0); _phase.finish_turn()   # RED 1
	_phase.try_place(0, Vector2i(2, 0), 0); _phase.finish_turn()   # BLUE 2 (last)
	assert_false(_phase.is_finished())
	_phase.try_place(0, Vector2i(3, 0), 0); _phase.finish_turn()   # RED 2 (last)
	assert_true(_phase.is_finished())
	assert_signal_emitted(_phase, "setup_finished")


func test_bridge_is_free_does_not_advance_and_keeps_the_block_counted() -> void:
	var board := Board.new()
	var blue := _player(PlayerColor.Kind.BLUE, 1)
	blue.bridge = _bridge()
	var phase := SetupPhase.new([blue] as Array[Player], board)
	phase.try_place(0, Vector2i.ZERO, 0)               # block at origin
	# Bridge central road (0,1) touches the road at (0,0): free, stays BLUE's turn.
	assert_true(phase.try_place_bridge(Vector2i(-1, 1), 0))
	assert_eq(phase.current_player().color, PlayerColor.Kind.BLUE, "bridge does not advance")
	assert_true(phase.block_placed_this_turn(), "the block still counts")
	assert_null(blue.bridge, "bridge consumed once placed")


func test_finish_with_only_the_bridge_left_finishes_and_abandons_it() -> void:
	var board := Board.new()
	var blue := _player(PlayerColor.Kind.BLUE, 1)
	blue.bridge = _bridge()
	var phase := SetupPhase.new([blue] as Array[Player], board)
	phase.try_place(0, Vector2i.ZERO, 0)               # last block placed; bridge still held
	assert_false(phase.is_finished())
	assert_true(phase.finish_turn(), "may finish with a block placed even though a bridge remains")
	assert_true(phase.is_finished(), "player done; the unplaced bridge is abandoned")


func test_remove_bridge_returns_it_to_the_player() -> void:
	var board := Board.new()
	var blue := _player(PlayerColor.Kind.BLUE, 1)
	blue.bridge = _bridge()
	var phase := SetupPhase.new([blue] as Array[Player], board)
	phase.try_place(0, Vector2i.ZERO, 0)
	phase.try_place_bridge(Vector2i(-1, 1), 0)
	assert_null(blue.bridge)
	assert_true(phase.remove_bridge())
	assert_not_null(blue.bridge, "bridge returned to the player")


func test_rotate_block_requires_a_placed_block() -> void:
	assert_false(_phase.rotate_block(1))


func test_rotate_block_snaps_to_the_next_valid_rotation() -> void:
	var board := Board.new()
	var blue := Player.new(PlayerColor.Kind.BLUE)
	blue.pieces.append(_road2())
	var phase := SetupPhase.new([blue] as Array[Player], board)
	board.place(_road2(), Vector2i.ZERO, 0)            # A: (0,0),(1,0)
	board.place(_road2(), Vector2i(1, 1), 0)           # C: (1,1),(2,1)  (obstacle, links to A)
	phase.try_place(0, Vector2i(2, 0), 0)              # B: (2,0),(3,0), rot 0
	assert_eq(phase.placed_block().rotation, 0)
	assert_true(phase.rotate_block(1))
	# Stepping B's free cell around (2,0): rot1 -> (2,1) [C], rot2 -> (1,1) [C], rot3 -> (1,0) [A] are
	# all blocked, so it snaps to rot4 -> (2,-1), the first free & connected orientation.
	assert_eq(phase.placed_block().rotation, 4, "snapped past the blocked rotations")
