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
