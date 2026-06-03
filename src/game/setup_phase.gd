class_name SetupPhase
extends RefCounted
## Drives the turn-by-turn setup placement. A turn = place exactly ONE block (which does NOT advance
## the turn), then optionally place the free bridge, then call [method finish_turn]. While the turn is
## open the placed block (and bridge) can be removed or rotated; re-positioning is the controller's
## job (remove + place again). [method finish_turn] is refused until a block is placed; once it runs,
## the player is done if no blocks remain (a leftover bridge is simply abandoned — a player never gets
## a turn with only a bridge to place). The phase ends once every player is done. Pure logic.

signal turn_changed(player: Player)        ## a new player's turn begins (or the phase advances)
signal turn_state_changed(player: Player)  ## within-turn change (place/remove/rotate) — refresh the UI
signal setup_finished

var _players: Array[Player]
var _board: Board
var _current: int = 0

var _turn_block: PlacedPiece = null        ## the block placed this turn (null until one is placed)
var _turn_block_index: int = -1            ## its original index in the player's tray (for removal)
var _turn_bridge: PlacedPiece = null       ## the bridge placed this turn, if any


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


## The block placed during the current turn, or null. Exposed so the controller can anchor the
## floating controls to it and pick it back up to re-position it.
func placed_block() -> PlacedPiece:
	return _turn_block


## The bridge placed during the current turn, or null.
func placed_bridge() -> PlacedPiece:
	return _turn_bridge


## True once a block has been placed this turn — the condition for ending the turn.
func block_placed_this_turn() -> bool:
	return _turn_block != null


## Places the current player's [param block_index] block. Does NOT advance the turn. Refused if a
## block is already placed this turn (one block per turn) or the placement is illegal. Returns success.
func try_place(block_index: int, anchor: Vector2i, rotation: int) -> bool:
	if _turn_block != null:
		return false
	var player := current_player()
	if block_index < 0 or block_index >= player.pieces.size():
		return false
	if not _board.place(player.pieces[block_index], anchor, rotation, player.color):
		return false
	_turn_block = _board.pieces().back()
	_turn_block_index = block_index
	player.pieces.remove_at(block_index)
	turn_state_changed.emit(player)
	return true


## Takes the placed block back off the board and returns it to the player's tray. Returns success.
func remove_block() -> bool:
	if _turn_block == null:
		return false
	var player := current_player()
	_board.remove_piece(_turn_block)
	player.pieces.insert(mini(_turn_block_index, player.pieces.size()), _turn_block.block_def)
	_turn_block = null
	_turn_block_index = -1
	turn_state_changed.emit(player)
	return true


## Rotates the placed block one 60-degree step in [param dir] (+1 / -1), snapping to the next valid
## rotation (skipping any that would overlap or break the road link). Returns success.
func rotate_block(dir: int) -> bool:
	if _turn_block == null:
		return false
	_turn_block = _rotate_in_place(_turn_block, dir)
	turn_state_changed.emit(current_player())
	return true


## Places the current player's free bridge. Does NOT advance the turn and does NOT mark the player
## done. Returns success.
func try_place_bridge(anchor: Vector2i, rotation: int) -> bool:
	var player := current_player()
	if player.bridge == null or _turn_bridge != null:
		return false
	if not _board.place(player.bridge, anchor, rotation, player.color):
		return false
	_turn_bridge = _board.pieces().back()
	player.bridge = null
	turn_state_changed.emit(player)
	return true


## Takes the placed bridge back off the board and returns it to the player. Returns success.
func remove_bridge() -> bool:
	if _turn_bridge == null:
		return false
	var player := current_player()
	_board.remove_piece(_turn_bridge)
	player.bridge = _turn_bridge.block_def
	_turn_bridge = null
	turn_state_changed.emit(player)
	return true


## Rotates the placed bridge one step in [param dir], snapping to the next valid rotation. Success.
func rotate_bridge(dir: int) -> bool:
	if _turn_bridge == null:
		return false
	_turn_bridge = _rotate_in_place(_turn_bridge, dir)
	turn_state_changed.emit(current_player())
	return true


## Ends the current turn. Refused unless a block was placed this turn. The player becomes done when no
## blocks remain (any unplaced bridge is abandoned), then the phase advances. Returns success.
func finish_turn() -> bool:
	if _turn_block == null:
		return false
	var player := current_player()
	_turn_block = null
	_turn_block_index = -1
	_turn_bridge = null
	if player.pieces.is_empty():
		player.done = true
	_advance()
	return true


# Removes [param piece] and re-places the same block at the first valid rotation found by stepping in
# [param dir]. The full turn (step 6) returns to the original rotation, which was valid, so this
# always re-places the piece. Returns the new PlacedPiece.
func _rotate_in_place(piece: PlacedPiece, dir: int) -> PlacedPiece:
	var block := piece.block_def
	var anchor := piece.anchor
	var owner := piece.owner
	var current := piece.rotation
	_board.remove_piece(piece)
	for step in range(1, 7):
		var rot := ((current + dir * step) % 6 + 6) % 6
		if _board.place(block, anchor, rot, owner):
			return _board.pieces().back()
	return _board.pieces().back()


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
