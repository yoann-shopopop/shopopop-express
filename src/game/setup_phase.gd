class_name SetupPhase
extends RefCounted
## Drives the turn-by-turn setup placement: players take turns placing one piece each, round-robin,
## until everyone has placed all their pieces. Delegates legality to the [Board]; knows nothing
## about rendering or input.

signal turn_changed(player: Player)
signal setup_finished

var _players: Array[Player]
var _board: Board
var _current: int = 0


func _init(players: Array[Player], board: Board) -> void:
	_players = players
	_board = board


func current_player() -> Player:
	return _players[_current]


## The current player's remaining pieces (what they can choose to place this turn).
func remaining_pieces() -> Array[BlockDefinition]:
	return current_player().pieces


func is_finished() -> bool:
	for player in _players:
		if not player.pieces.is_empty():
			return false
	return true


## Tries to place the current player's [param piece_index] piece. On success, consumes the piece and
## advances the turn. Returns whether the placement was legal.
func try_place(piece_index: int, anchor: Vector2i, rotation: int) -> bool:
	var player := current_player()
	if piece_index < 0 or piece_index >= player.pieces.size():
		return false
	var block := player.pieces[piece_index]
	if not _board.place(block, anchor, rotation, player.color):
		return false
	player.pieces.remove_at(piece_index)
	_advance()
	return true


## Atomically places the current player's bridge + their [param block_index] block in ONE turn,
## consuming both. The bridge is free and can never be placed on its own. Returns false if the
## player has no bridge left or the placement is illegal.
func try_place_with_bridge(block_index: int, block_anchor: Vector2i, block_rot: int, bridge_anchor: Vector2i, bridge_rot: int) -> bool:
	var player := current_player()
	if block_index < 0 or block_index >= player.pieces.size() or player.bridge == null:
		return false
	var block := player.pieces[block_index]
	var bridge := player.bridge

	# No overlap for either piece.
	for c in bridge.get_cells(bridge_anchor, bridge_rot):
		if _board.is_occupied(c):
			return false
	for c in block.get_cells(block_anchor, block_rot):
		if _board.is_occupied(c):
			return false
	# The bridge must link an existing ROAD to the new block's ROAD (one end each) — never water.
	if not _bridge_links(
			bridge.get_connectors(bridge_anchor, bridge_rot),
			block.get_connectors(block_anchor, block_rot),
			_board.connector_cells()):
		return false

	_board.place(bridge, bridge_anchor, bridge_rot, player.color, false)
	_board.place(block, block_anchor, block_rot, player.color, false)
	player.pieces.remove_at(block_index)
	player.bridge = null
	_advance()
	return true


# One bridge end touches a board road, the other touches the new block's road.
func _bridge_links(bridge_ends: Array[Vector2i], block_roads: Array[Vector2i], board_roads: Array[Vector2i]) -> bool:
	for i in bridge_ends.size():
		var other := bridge_ends[(i + 1) % bridge_ends.size()]
		if _connects([bridge_ends[i]] as Array[Vector2i], board_roads) and _connects([other] as Array[Vector2i], block_roads):
			return true
	return false


# True if any cell in [param a] is a hex-neighbor of any cell in [param b].
func _connects(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	for ca in a:
		for cb in b:
			if HexUtils.are_adjacent(ca, cb):
				return true
	return false


# Moves to the next player who still has pieces, or finishes the phase.
func _advance() -> void:
	if is_finished():
		setup_finished.emit()
		return
	for _i in _players.size():
		_current = (_current + 1) % _players.size()
		if not _players[_current].pieces.is_empty():
			break
	turn_changed.emit(current_player())
