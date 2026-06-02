extends GutTest
## Tests for SetupPhase — turn-by-turn placement, one piece per turn, until everything is placed.

var _board: Board
var _phase: SetupPhase


func _road_tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"road"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	return b


func _bridge() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"bridge"
	b.cells = BlockDefinition.make_line_cells(3)
	b.cell_types = [CellType.Kind.WATER, CellType.Kind.ROUTE, CellType.Kind.WATER]
	b.connectors = [Vector2i(0, 0), Vector2i(2, 0)] as Array[Vector2i]
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


func test_a_valid_placement_advances_to_the_next_player() -> void:
	assert_true(_phase.try_place(0, Vector2i.ZERO, 0))
	assert_eq(_phase.current_player().color, PlayerColor.Kind.RED)


func test_an_invalid_placement_keeps_the_turn() -> void:
	_phase.try_place(0, Vector2i.ZERO, 0)            # BLUE places at origin -> RED's turn
	# RED tries to place far away (no road-to-road connection) -> rejected.
	assert_false(_phase.try_place(0, Vector2i(9, 9), 0))
	assert_eq(_phase.current_player().color, PlayerColor.Kind.RED, "still RED's turn")


func test_round_robin_returns_to_first_player() -> void:
	_phase.try_place(0, Vector2i.ZERO, 0)            # BLUE
	_phase.try_place(0, Vector2i(1, 0), 0)           # RED, adjacent
	assert_eq(_phase.current_player().color, PlayerColor.Kind.BLUE, "back to BLUE for round 2")


func test_auto_bridge_places_both_and_consumes_the_bridge() -> void:
	var board := Board.new()
	var blue := _player(PlayerColor.Kind.BLUE, 1)
	var red := Player.new(PlayerColor.Kind.RED)
	red.pieces = [_road_tile(), _bridge()] as Array[BlockDefinition]
	var phase := SetupPhase.new([blue, red] as Array[Player], board)

	phase.try_place(0, Vector2i.ZERO, 0)              # BLUE road at origin -> RED's turn
	var bridge := BridgeFinder.find(board, red.pieces[0], Vector2i(4, 0), 0, red.pieces[1])
	assert_false(bridge.is_empty(), "a linking bridge exists")
	assert_true(phase.try_place_with_bridge(0, Vector2i(4, 0), 0, bridge["anchor"], bridge["rotation"]))
	assert_eq(board.pieces().size(), 3, "BLUE road + bridge + RED road")
	assert_eq(red.pieces.size(), 0, "block and bridge both consumed")


func test_auto_bridge_fails_without_a_bridge() -> void:
	var board := Board.new()
	var blue := _player(PlayerColor.Kind.BLUE, 1)
	var red := _player(PlayerColor.Kind.RED, 1)  # only a road, no bridge
	var phase := SetupPhase.new([blue, red] as Array[Player], board)
	phase.try_place(0, Vector2i.ZERO, 0)
	assert_false(phase.try_place_with_bridge(0, Vector2i(4, 0), 0, Vector2i(1, 0), 0))


func test_phase_finishes_when_all_pieces_are_placed() -> void:
	watch_signals(_phase)
	_phase.try_place(0, Vector2i.ZERO, 0)            # BLUE
	_phase.try_place(0, Vector2i(1, 0), 0)           # RED
	_phase.try_place(0, Vector2i(2, 0), 0)           # BLUE
	assert_false(_phase.is_finished())
	_phase.try_place(0, Vector2i(3, 0), 0)           # RED, last piece
	assert_true(_phase.is_finished())
	assert_signal_emitted(_phase, "setup_finished")
