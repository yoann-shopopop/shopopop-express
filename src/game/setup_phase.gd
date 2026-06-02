class_name SetupPhase
extends RefCounted
## Drives the turn-by-turn setup placement. On a turn a player MAY first place their bridge (free —
## it does not end the turn, and must connect to a road), then places a block (which ends the turn).
## A bridge dropped one cell too far auto-inserts the bridge with the block. When a player has no
## blocks left they may place their bridge or end (pass). The phase ends once every player is done.
## Pure logic — no rendering/input.

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


func is_finished() -> bool:
	for player in _players:
		if not player.done:
			return false
	return true


## Places the current player's [param block_index] block and ends the turn. Returns success.
func try_place(block_index: int, anchor: Vector2i, rotation: int) -> bool:
	var player := current_player()
	if block_index < 0 or block_index >= player.pieces.size():
		return false
	if not _board.place(player.pieces[block_index], anchor, rotation, player.color):
		return false
	player.pieces.remove_at(block_index)
	_update_done(player)
	_advance()
	return true


## Places the current player's bridge — FREE: it must connect to a road and does NOT end the turn,
## unless the player then has nothing left to place (then they're done). Returns success.
func try_place_bridge(anchor: Vector2i, rotation: int) -> bool:
	var player := current_player()
	if player.bridge == null:
		return false
	if not _board.place(player.bridge, anchor, rotation, player.color):
		return false
	player.bridge = null
	if player.pieces.is_empty():
		player.done = true
		_advance()
	else:
		turn_changed.emit(player)  # same turn continues; refresh (bridge consumed)
	return true


## Ends the current player's turn without placing a block — only allowed when they have no blocks
## left (they keep, or skip, their bridge). Returns success.
func pass_turn() -> bool:
	var player := current_player()
	if not player.pieces.is_empty():
		return false
	player.done = true
	_advance()
	return true


## Auto-bridge: places the bridge + the [param block_index] block in one turn (the bridge bridging an
## existing road and the block's road). Consumes both and ends the turn.
func try_place_with_bridge(block_index: int, block_anchor: Vector2i, block_rot: int, bridge_anchor: Vector2i, bridge_rot: int) -> bool:
	var player := current_player()
	if block_index < 0 or block_index >= player.pieces.size() or player.bridge == null:
		return false
	var block := player.pieces[block_index]
	var bridge := player.bridge

	for c in bridge.get_cells(bridge_anchor, bridge_rot):
		if _board.is_occupied(c):
			return false
	for c in block.get_cells(block_anchor, block_rot):
		if _board.is_occupied(c):
			return false
	if not _bridge_links(
			bridge.get_connectors(bridge_anchor, bridge_rot),
			block.get_connectors(block_anchor, block_rot),
			_board.connector_cells()):
		return false

	_board.place(bridge, bridge_anchor, bridge_rot, player.color, false)
	_board.place(block, block_anchor, block_rot, player.color, false)
	player.pieces.remove_at(block_index)
	player.bridge = null
	_update_done(player)
	_advance()
	return true


func _update_done(player: Player) -> void:
	if player.pieces.is_empty() and player.bridge == null:
		player.done = true


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


# Moves to the next player who isn't done, or finishes the phase.
func _advance() -> void:
	if is_finished():
		setup_finished.emit()
		return
	for _i in _players.size():
		_current = (_current + 1) % _players.size()
		if not _players[_current].done:
			break
	turn_changed.emit(current_player())
