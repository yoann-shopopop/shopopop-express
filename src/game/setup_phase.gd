class_name SetupPhase
extends RefCounted
## Drives the turn-by-turn setup placement. On a turn a player MAY first place their bridge (free —
## it does not end the turn, and connects to a road via its central road cell only), then places a
## block (which ends the turn). When a player has no blocks left they may place their bridge or end
## (pass). The phase ends once every player is done. Pure logic — no rendering/input.

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


func _update_done(player: Player) -> void:
	if player.pieces.is_empty() and player.bridge == null:
		player.done = true


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
