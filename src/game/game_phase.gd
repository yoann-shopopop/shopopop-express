class_name GamePhase
extends RefCounted
## Orchestrates the play phase after setup: each turn runs through sub-phases (planning, movement,
## events, pickup, delivery) and then passes to the next player, round-robin. Pure logic — no nodes,
## no dice (the budget is injected via [method begin_movement]); the view/controller drive it through
## signals. Mirrors [SetupPhase] for the turn-advance pattern.
##
## The cell positions of the pawns are the authority here ([method position_of]); the view mirrors
## them through [signal pawn_moved]. Phase A only uses PLANIFICATION/DEPLACEMENT/FIN_TOUR.

enum SubPhase { PLANIFICATION, DEPLACEMENT, EVENEMENT, PRISE_EN_CHARGE, LIVRAISON, FIN_TOUR }

## The active player changed.
signal turn_changed(player: Player)
## The current sub-phase changed.
signal subphase_changed(subphase: int)
## A pawn moved from one cell to another.
signal pawn_moved(player: Player, from: Vector2i, to: Vector2i)
## A delivery was reserved by the current player during planning.
signal delivery_picked(delivery: Delivery)
## A delivery was completed; [param points] were awarded to its carrier.
signal delivery_completed(delivery: Delivery, points: int)
## The game ended (all deliveries done); [param scores] maps player index -> total.
signal game_finished(scores: Dictionary)
## The pawn stepped onto an event (rainbow) cell — draw and resolve an event card.
signal event_triggered(cell: Vector2i)

var _players: Array[Player]
var _board: Board
var _deliveries: Array[Delivery] = []
var _current: int = 0
var _subphase: int = SubPhase.PLANIFICATION
var _positions: Dictionary = {}        # player index -> absolute Vector2i cell
var _scores: Dictionary = {}           # player index -> total points
var _carrying: Dictionary = {}         # player index -> the Delivery being carried (or absent)
var _movement: TurnMovement = null
var _context: TurnContext = null       # mutable state for the current turn's events/powers


func _init(players: Array[Player], board: Board, deliveries: Array[Delivery] = []) -> void:
	_players = players
	_board = board
	_deliveries = deliveries
	for player in players:
		_positions[player.index] = _absolute_start_cell(player)
		_scores[player.index] = 0


## The player whose turn it is.
func current_player() -> Player:
	return _players[_current]


## The current sub-phase ([enum SubPhase]).
func current_subphase() -> int:
	return _subphase


## The board cell a player's pawn currently occupies.
func position_of(player: Player) -> Vector2i:
	return _positions[player.index]


## The movement in progress this turn (null outside DEPLACEMENT).
func movement() -> TurnMovement:
	return _movement


## Starts the current player's movement with [param budget] steps (from the dice). Builds the
## walkable road network from the board and enters DEPLACEMENT.
func begin_movement(budget: int) -> void:
	if _subphase != SubPhase.PLANIFICATION:
		return
	var walkable := RoadNetwork.walkable_from_board(_board)
	_movement = TurnMovement.new(walkable, position_of(current_player()), budget)
	_context = TurnContext.new(_movement, current_player())
	_context.current_delivery = current_delivery()
	_set_subphase(SubPhase.DEPLACEMENT)


## Tries to step the current pawn onto [param cell]. Only valid during DEPLACEMENT. Stepping onto an
## event cell pauses movement (EVENEMENT) and emits [signal event_triggered].
func try_step(cell: Vector2i) -> bool:
	if _subphase != SubPhase.DEPLACEMENT or _movement == null:
		return false
	var from := _movement.current()
	if not _movement.step(cell):
		return false
	_positions[current_player().index] = cell
	pawn_moved.emit(current_player(), from, cell)
	if _board.cell_type_at(cell) == CellType.Kind.EVENT:
		_set_subphase(SubPhase.EVENEMENT)
		event_triggered.emit(cell)
	return true


## Ends the current turn and passes to the next player (round-robin), back to PLANIFICATION.
func end_turn() -> void:
	_movement = null
	_context = null
	_current = (_current + 1) % _players.size()
	_set_subphase(SubPhase.PLANIFICATION)
	turn_changed.emit(current_player())


# --- Events & powers --------------------------------------------------------

## The current turn's mutable context (null outside a movement).
func context() -> TurnContext:
	return _context


## Resolves a drawn event [param card] against the current turn, then resumes (or ends) the turn.
func apply_event(card: EventCardDefinition) -> void:
	if _context == null:
		return
	EventResolver.resolve(card, _context)
	if _context.score_bonus != 0:
		_scores[_current] += _context.score_bonus
		_context.score_bonus = 0
	if _context.turn_ended:
		_set_subphase(SubPhase.FIN_TOUR)
	elif _subphase == SubPhase.EVENEMENT:
		_set_subphase(SubPhase.DEPLACEMENT)


## Activates the current player's one-shot super-power. Returns false if unavailable/already used.
func use_power() -> bool:
	if _context == null:
		return false
	var character := current_player().character
	if character == null:
		return false
	return PowerResolver.resolve(character.power_id, _context)


# --- Deliveries -------------------------------------------------------------

## Deliveries that can still be reserved: not delivered and not already carried by anyone.
func available_deliveries() -> Array[Delivery]:
	var result: Array[Delivery] = []
	for delivery in _deliveries:
		if not delivery.delivered and delivery.carrier_index < 0:
			result.append(delivery)
	return result


## The delivery the current player is carrying, or null.
func current_delivery() -> Delivery:
	return _carrying.get(_current, null)


## Reserves [param delivery] for the current player (only during planning, if still available).
func select_delivery(delivery: Delivery) -> bool:
	if _subphase != SubPhase.PLANIFICATION or delivery == null:
		return false
	if delivery.delivered or delivery.carrier_index >= 0:
		return false
	delivery.carrier_index = _current
	_carrying[_current] = delivery
	delivery_picked.emit(delivery)
	return true


## Picks up a delivery at its drive — costs +1 step. Valid on or next to the drive cell. If the player
## isn't carrying one yet, the available delivery at this drive is reserved automatically (no separate
## planning step).
func confirm_pickup() -> bool:
	if _movement == null:
		return false
	var delivery := current_delivery()
	if delivery == null:
		delivery = _available_delivery_at(_movement.current())
		if delivery == null:
			return false
		delivery.carrier_index = _current
		_carrying[_current] = delivery
		delivery_picked.emit(delivery)
	if delivery.picked_up or HexUtils.distance(_movement.current(), delivery.drive_cell) > 1:
		return false
	_movement.subtract_steps(1)
	delivery.picked_up = true
	return true


# An available delivery whose drive is on or next to [param cell], or null.
func _available_delivery_at(cell: Vector2i) -> Delivery:
	for delivery in _deliveries:
		if not delivery.delivered and delivery.carrier_index < 0 \
				and HexUtils.distance(cell, delivery.drive_cell) <= 1:
			return delivery
	return null


## Delivers the carried delivery at its recipient — free. Valid on or next to the recipient cell.
func confirm_delivery() -> bool:
	var delivery := current_delivery()
	if delivery == null or not delivery.picked_up or delivery.delivered:
		return false
	if _movement == null or HexUtils.distance(_movement.current(), delivery.recipient_cell) > 1:
		return false
	delivery.delivered = true
	var points := _score_for(current_player(), delivery)
	if _context != null and _context.double_score:
		points *= 2  # Livraison Écologique
	_scores[_current] += points
	_carrying.erase(_current)
	delivery_completed.emit(delivery, points)
	if is_finished():
		game_finished.emit(scores())
	return true


## Total points scored by [param player].
func score_of(player: Player) -> int:
	return _scores.get(player.index, 0)


## All players' totals, keyed by seat index.
func scores() -> Dictionary:
	return _scores.duplicate()


## True once every delivery is done (false while there are none, so a freshly built game isn't "over").
func is_finished() -> bool:
	if _deliveries.is_empty():
		return false
	for delivery in _deliveries:
		if not delivery.delivered:
			return false
	return true


func _score_for(player: Player, delivery: Delivery) -> int:
	if player.character == null:
		return ScoreCalculator.BASE
	return ScoreCalculator.score_delivery(delivery, player.character)


func _set_subphase(subphase: int) -> void:
	_subphase = subphase
	subphase_changed.emit(subphase)


# The absolute board cell of a player's start, found from its placed start block (same formula as
# the view). Falls back to the raw offset if the block is not on the board.
func _absolute_start_cell(player: Player) -> Vector2i:
	if player.start_block != null:
		for piece in _board.pieces():
			if piece.block_def == player.start_block:
				return HexUtils.rotate(player.start_cell, piece.rotation) + piece.anchor
	return player.start_cell
