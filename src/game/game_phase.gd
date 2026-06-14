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
## A delivery was reserved by the current player (stepping onto its tile).
signal delivery_reserved(delivery: Delivery)
## A reserved delivery became EN_COURS (the pawn reached its drive cell).
signal delivery_in_progress(delivery: Delivery)
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
var _round: int = 1
var _subphase: int = SubPhase.PLANIFICATION
var _positions: Dictionary = {}        # player index -> absolute Vector2i cell
var _scores: Dictionary = {}           # player index -> total points
var _movement: TurnMovement = null
var _context: TurnContext = null       # mutable state for the current turn's events/powers
var _generator: DeliveryGenerator = null  # when set, delivering recycles a new recipient (index-aligned with _deliveries)

## Maximum in-flight deliveries (RESERVE + EN_COURS) a player may hold simultaneously.
const MAX_IN_FLIGHT := 2


func _init(players: Array[Player], board: Board, deliveries: Array[Delivery] = [], generator: DeliveryGenerator = null) -> void:
	_players = players
	_board = board
	_deliveries = deliveries
	_generator = generator
	for player in players:
		_positions[player.index] = _absolute_start_cell(player)
		_scores[player.index] = 0


## The player whose turn it is.
func current_player() -> Player:
	return _players[_current]


## The current round number (1-based): increments each time play wraps back to the first seat.
func round_number() -> int:
	return _round


## How many deliveries are still to be made before the game ends — the recipients still clipped on a
## tile plus those waiting in the recycling pool. Reaches zero exactly when [method is_finished] holds.
func deliveries_remaining() -> int:
	var count := 0
	for delivery in _deliveries:
		if delivery.destinataire != null:
			count += 1
	if _generator != null:
		count += _generator.remaining_recipients()
	return count


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
	# Movement is roads-only, but the drive (urban) and recipient (green) cells of every delivery are
	# reachable destinations: the pawn must be able to step onto them (off the road) to pick up/deliver.
	for delivery in _deliveries:
		walkable[delivery.drive_cell] = true
		walkable[delivery.recipient_cell] = true
	_movement = TurnMovement.new(walkable, position_of(current_player()), budget)
	_context = TurnContext.new(_movement, current_player())
	_context.current_delivery = _primary_delivery(_current)
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
	_check_delivery_transitions()
	if _board.cell_type_at(cell) == CellType.Kind.EVENT:
		_set_subphase(SubPhase.EVENEMENT)
		event_triggered.emit(cell)
	return true


## Ends the current turn and passes to the next player (round-robin), back to PLANIFICATION. When the
## turn earned a replay (Tous les Feux au Vert), the SAME player plays again: no seat advance and no
## new round — the view re-arms the roll on [signal turn_changed].
func end_turn() -> void:
	var replay := _context != null and _context.replay
	_movement = null
	_context = null
	if replay:
		_set_subphase(SubPhase.PLANIFICATION)
		turn_changed.emit(current_player())
		return
	_current = (_current + 1) % _players.size()
	if _current == 0:
		_round += 1  # play wrapped back to the first seat: a new round begins
	_set_subphase(SubPhase.PLANIFICATION)
	turn_changed.emit(current_player())


# --- Events & powers --------------------------------------------------------

## The current turn's mutable context (null outside a movement).
func context() -> TurnContext:
	return _context


## Resolves a drawn event [param card] against the current turn, then resumes (or ends) the turn. A
## malus is cancelled outright when the player has Bouclier Vert armed (the shield is then spent).
func apply_event(card: EventCardDefinition) -> void:
	if _context == null:
		return
	var player := current_player()
	if card.is_malus and player.shield_charged:
		player.shield_charged = false
		_context.shield_consumed = true
		if _subphase == SubPhase.EVENEMENT:
			_set_subphase(SubPhase.DEPLACEMENT)
		return
	EventResolver.resolve(card, _context)
	if _context.score_bonus != 0:
		_scores[_current] += _context.score_bonus
		_context.score_bonus = 0
	if _context.turn_ended:
		_set_subphase(SubPhase.FIN_TOUR)
	elif _subphase == SubPhase.EVENEMENT:
		_set_subphase(SubPhase.DEPLACEMENT)


## Activates the current player's NON-interactive one-shot super-power. Interactive powers
## (Dépassement, Coup d'Accélérateur) are handled by [method swap_positions] / [method apply_reroll].
## Returns false if unavailable/already used/interactive. Applies effects the resolver only flags
## (Passage Secret opens the water).
func use_power() -> bool:
	if _context == null:
		return false
	var character := current_player().character
	if character == null:
		return false
	if PowerResolver.is_interactive(character.power_id):
		return false
	if not PowerResolver.resolve(character.power_id, _context):
		return false
	if _context.water_crossing:
		_open_water_crossing()
	return true


# Passage Secret (Gégé): make every water cell passable for the rest of this turn.
func _open_water_crossing() -> void:
	if _movement == null:
		return
	var water := {}
	for cell in _board.cells_of_type(CellType.Kind.WATER):
		water[cell] = true
	_movement.allow_cells(water)


## Dépassement (Sam): swaps the current pawn's cell with player [param other_index]'s, consuming the
## one-shot. The acting pawn's movement continues from the new cell. Returns false if unavailable or
## the target is invalid.
func swap_positions(other_index: int) -> bool:
	if _context == null or _subphase != SubPhase.DEPLACEMENT:
		return false
	var player := current_player()
	if player.character == null or player.power_used or player.character.power_id != &"depassement":
		return false
	if other_index == player.index or not _positions.has(other_index):
		return false
	var mine: Vector2i = _positions[player.index]
	var theirs: Vector2i = _positions[other_index]
	_positions[player.index] = theirs
	_positions[other_index] = mine
	if _movement != null:
		_movement.teleport_to(theirs)
	player.power_used = true
	pawn_moved.emit(player, mine, theirs)
	pawn_moved.emit(_players[other_index], theirs, mine)
	_check_delivery_transitions()
	return true


## Coup d'Accélérateur (Vic): adjusts the turn budget by [param delta] (new die value − old) after the
## view re-rolled a die, consuming the one-shot. Returns false if unavailable.
func apply_reroll(delta: int) -> bool:
	if _context == null or _subphase != SubPhase.DEPLACEMENT or _movement == null:
		return false
	var player := current_player()
	if player.character == null or player.power_used or player.character.power_id != &"coup_accelerateur":
		return false
	if delta >= 0:
		_movement.add_steps(delta)
	else:
		_movement.subtract_steps(-delta)
	player.power_used = true
	return true


# --- Deliveries -------------------------------------------------------------

## Deliveries still reservable: DISPONIBLE with a recipient clipped (drive not "free").
func available_deliveries() -> Array[Delivery]:
	var result: Array[Delivery] = []
	for delivery in _deliveries:
		if delivery.is_reservable():
			result.append(delivery)
	return result


## In-flight deliveries (RESERVE or EN_COURS) held by [param player_index].
func deliveries_in_flight(player_index: int) -> Array[Delivery]:
	var result: Array[Delivery] = []
	for delivery in _deliveries:
		if delivery.reserved_by == player_index \
				and (delivery.status == DeliveryStatus.Kind.RESERVE \
					or delivery.status == DeliveryStatus.Kind.EN_COURS):
			result.append(delivery)
	return result


## The reservable delivery on the current pawn's tile, or null. Requires the player to hold fewer than
## [constant MAX_IN_FLIGHT] deliveries. Only the drive tile is checked (tiles[0]).
func reservable_delivery() -> Delivery:
	if deliveries_in_flight(_current).size() >= MAX_IN_FLIGHT + current_player().bonus_capacity:
		return null
	var tile := _board.piece_at(position_of(current_player()))
	if tile == null:
		return null
	for delivery in _deliveries:
		if delivery.is_reservable() and not delivery.tiles.is_empty() and delivery.tiles[0] == tile:
			return delivery
	return null


## Reserves the delivery on the current tile for the current player (only during DEPLACEMENT).
func reserve_delivery() -> bool:
	if _subphase != SubPhase.DEPLACEMENT:
		return false
	var delivery := reservable_delivery()
	if delivery == null:
		return false
	delivery.status = DeliveryStatus.Kind.RESERVE
	delivery.reserved_by = _current
	delivery_reserved.emit(delivery)
	_check_delivery_transitions()
	return true


# Drives automatic transitions from the current pawn position; called after each step and after a
# reservation. RESERVE -> EN_COURS on the drive cell; EN_COURS -> delivery on the recipient cell.
func _check_delivery_transitions() -> void:
	var cell := position_of(current_player())
	for delivery in deliveries_in_flight(_current):
		if delivery.status == DeliveryStatus.Kind.RESERVE and cell == delivery.drive_cell:
			delivery.status = DeliveryStatus.Kind.EN_COURS
			delivery_in_progress.emit(delivery)
		elif delivery.status == DeliveryStatus.Kind.EN_COURS and cell == delivery.recipient_cell:
			_complete_delivery(delivery)
	if _context != null:
		_context.current_delivery = _primary_delivery(_current)


# Scores [param delivery], recycles a new recipient (or leaves the drive free), checks for game end.
func _complete_delivery(delivery: Delivery) -> void:
	var player := current_player()
	var points := _score_for(player, delivery)
	if player.regular_route_charge:
		points = maxi(points, ScoreCalculator.full_score())  # Habitué·e: count as if on your colour
		player.regular_route_charge = false
	if _context != null and _context.double_score:
		points *= 2  # Livraison Écologique
	_scores[_current] += points
	if _generator != null:
		var idx := _deliveries.find(delivery)
		var next: DestinataireDefinition = null
		if idx >= 0:
			next = _generator.recycle(idx)
		delivery.recycle(next)
	else:
		delivery.recycle(null)  # no recycling source: the drive is done
	delivery_completed.emit(delivery, points)
	if is_finished():
		game_finished.emit(scores())


# The delivery "in hand" for [param player_index]: the EN_COURS one if any, else a RESERVE one, else
# null. Used by event teleports.
func _primary_delivery(player_index: int) -> Delivery:
	var reserved: Delivery = null
	for delivery in deliveries_in_flight(player_index):
		if delivery.status == DeliveryStatus.Kind.EN_COURS:
			return delivery
		reserved = delivery
	return reserved


## Total points scored by [param player].
func score_of(player: Player) -> int:
	return _scores.get(player.index, 0)


## All players' totals, keyed by seat index.
func scores() -> Dictionary:
	return _scores.duplicate()


## True once no delivery remains actionable: every delivery is DISPONIBLE with no recipient (pool
## exhausted, nothing in flight). False on a board that never had a delivery.
func is_finished() -> bool:
	if _deliveries.is_empty():
		return false
	for delivery in _deliveries:
		if delivery.status != DeliveryStatus.Kind.DISPONIBLE or delivery.destinataire != null:
			return false
	return true


func _score_for(player: Player, delivery: Delivery) -> int:
	return ScoreCalculator.score_delivery(delivery, player.color)


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
