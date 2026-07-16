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
## [param player]'s turn was skipped: they hold nothing and nothing is reservable (their day is over).
signal turn_skipped(player: Player)
## The pawn stepped onto an event (rainbow) cell — draw and resolve an event card.
signal event_triggered(cell: Vector2i)
## An event cell was consumed by triggering: it stays inert until the next round re-arms it.
signal event_cell_spent(cell: Vector2i)
## A new round began: every consumed event cell is armed again.
signal event_cells_rearmed

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
var _spent_event_cells: Dictionary = {}  # event cells consumed this round (set); re-armed each round
var _undo_barrier: int = 0  # movement().path().size() the player may not undo_step() back past (task #28)

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


## The recycling generator, or null if deliveries never recycle (e.g. a forced/scripted session).
## Exposed so the HUD can peek the upcoming recipients (see [method DeliveryGenerator.peek_upcoming]).
func generator() -> DeliveryGenerator:
	return _generator


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
	_undo_barrier = 1  # the path starts at the current cell alone — nothing to undo past it yet
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
	if _check_delivery_transitions():
		_undo_barrier = _movement.path().size()  # a pickup/delivery just happened: can't undo past it
	# An event cell triggers once, then is consumed for the round: crossing it back and forth cannot
	# farm the deck, and passing through a spent cell no longer interrupts the walk.
	if _board.cell_type_at(cell) == CellType.Kind.EVENT and is_event_cell_armed(cell):
		_spent_event_cells[cell] = true
		event_cell_spent.emit(cell)
		_undo_barrier = _movement.path().size()  # about to draw a card: can't undo past seeing it
		_set_subphase(SubPhase.EVENEMENT)
		event_triggered.emit(cell)
	return true


## True while at least one step taken this turn can still be undone. Blocked once the pawn has
## crossed a barrier — an automatic pickup, a completed delivery, or an event cell trigger — since
## undoing past one of those would un-happen scored points or "unsee" a drawn card, not just retrace
## a walk (see CLAUDE.md's "Undo jusqu'à information révélée").
func can_undo_step() -> bool:
	return _subphase == SubPhase.DEPLACEMENT and _movement != null and _movement.path().size() > _undo_barrier


## Undoes the last step taken this turn (refunds its budget), if [method can_undo_step] allows it.
func undo_step() -> bool:
	if not can_undo_step():
		return false
	var from := _movement.current()
	if not _movement.undo_step():
		return false
	var to := _movement.current()
	_positions[current_player().index] = to
	pawn_moved.emit(current_player(), from, to)
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
	_advance_seat()
	_skip_idle_players()
	_set_subphase(SubPhase.PLANIFICATION)
	turn_changed.emit(current_player())


func _advance_seat() -> void:
	_current = (_current + 1) % _players.size()
	if _current == 0:
		_round += 1  # play wrapped back to the first seat: a new round begins
		_rearm_event_cells()


# End-game tail: a player holding no in-flight delivery while nothing is reservable can no longer
# deliver anything (the identity pool is capped — no new recipient will ever appear), so their turns
# are skipped (announced via [signal turn_skipped]) instead of forcing empty roll-walk-end turns
# while the others finish. Assumed trade-off: a skipped player also forgoes walking to a still-armed
# event cell for a random score card — acceptable because the tail stops re-arming cells (see
# _rearm_event_cells), so that chance is bounded and the anticlimax fix wins. Bounded by the seat
# count: while the game is unfinished at least one player can act.
func _skip_idle_players() -> void:
	if _deliveries.is_empty() or is_finished():
		return  # no delivery game at all (bare-board demos), or nothing left: nothing to skip
	for _attempt in _players.size():
		var player := current_player()
		if not deliveries_in_flight(player.index).is_empty() or not available_deliveries().is_empty():
			return
		turn_skipped.emit(player)
		_advance_seat()


## True while the event (rainbow) cell at [param cell] can still trigger this round.
func is_event_cell_armed(cell: Vector2i) -> bool:
	return not _spent_event_cells.has(cell)


## The event cells consumed this round (armed again when a new round begins).
func spent_event_cells() -> Array:
	return _spent_event_cells.keys()


func _rearm_event_cells() -> void:
	if _spent_event_cells.is_empty():
		return
	# The endgame tail re-arms nothing: once fewer deliveries remain than players, permanently
	# skipped seats make every turn of the last active player(s) wrap into a "new round" — re-arming
	# there would let them farm event cards (+20s…) turn after turn instead of ending the game.
	# Boards without deliveries (demos, tests) keep the plain per-round re-arm.
	if not _deliveries.is_empty() and deliveries_remaining() <= _players.size():
		return
	_spent_event_cells.clear()
	event_cells_rearmed.emit()


# --- Events & powers --------------------------------------------------------

## The current turn's mutable context (null outside a movement).
func context() -> TurnContext:
	return _context


## Resolves a drawn event [param card] against the current turn, then resumes (or ends) the turn. A
## malus is cancelled outright when the player has Bouclier Vert armed (the shield is then spent).
## Any teleport the effect performs (returns, escort, rifts) is propagated to the authoritative pawn
## position and the view via [method _sync_pawn_after_event] — otherwise the pawn would not move.
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
	var from: Vector2i = _movement.current() if _movement != null else Vector2i.ZERO
	EventResolver.resolve(card, _context)        # pure effects (budget, flags, return/escort teleports)
	_apply_spatial_event(card)                    # board-dependent effects (rifts, shortcuts, blockages)
	_sync_pawn_after_event(from)                  # propagate any teleport to _positions + view + deliveries
	if _context.score_bonus != 0:
		_scores[_current] += _context.score_bonus
		_context.score_bonus = 0
	if _context.turn_ended:
		_set_subphase(SubPhase.FIN_TOUR)
	elif _subphase == SubPhase.EVENEMENT:
		_set_subphase(SubPhase.DEPLACEMENT)


# Board-dependent event effects that EventResolver (pure, ctx-only) can't do. Kept impactful + simple
# in V1: rifts/shortcuts teleport the pawn, blockages cost a detour. See CLAUDE.md "événements".
func _apply_spatial_event(card: EventCardDefinition) -> void:
	if _movement == null:
		return
	var from := _movement.current()
	match card.effect:
		EventCardDefinition.Effect.TELEPORT_QUARTIER:        # Faille Spatio-Temporelle: flung to a far district
			var cell = _farthest_drive_cell(from)
			if cell != null:
				_movement.teleport_to(cell)
		EventCardDefinition.Effect.TELEPORT_PARALLELE:       # Raccourci Secret: jump to the next pickup
			var cell = _nearest_available_drive(from)
			if cell != null:
				_movement.teleport_to(cell)
		EventCardDefinition.Effect.BUDGET_UN_DE:             # Manifestation: bottleneck, lose half the budget
			_movement.subtract_steps(_movement.remaining() / 2)
		EventCardDefinition.Effect.ROUTE_BLOQUEE:            # Fuite de Canalisation: a 3-step detour
			_movement.subtract_steps(3)
		EventCardDefinition.Effect.PONTS_FERMES:             # Pluies Torrentielles: bridges closed, 2-step detour
			_movement.subtract_steps(2)
		_:
			pass


# After an event, if the movement cursor moved (a teleport), make it the authoritative position, notify
# the view, and run the delivery transitions (e.g. an escort onto the recipient completes the delivery).
func _sync_pawn_after_event(from: Vector2i) -> void:
	if _movement == null:
		return
	var to := _movement.current()
	if to == from:
		return
	_positions[_current] = to
	pawn_moved.emit(current_player(), from, to)
	_check_delivery_transitions()
	if _movement != null:
		_undo_barrier = _movement.path().size()  # a teleport just happened: undo_step() must never pop it


# The drive cell of the delivery farthest from [param from] (a big relocation). null if none.
func _farthest_drive_cell(from: Vector2i):
	var best = null
	var best_dist := -1
	for delivery in _deliveries:
		if delivery.drive_cell == from:
			continue
		var dist := HexUtils.distance(from, delivery.drive_cell)
		if dist > best_dist:
			best_dist = dist
			best = delivery.drive_cell
	return best


# The drive cell of the nearest still-reservable delivery (a shortcut to the next pickup). null if none.
func _nearest_available_drive(from: Vector2i):
	var best = null
	var best_dist := 1 << 30
	for delivery in _deliveries:
		if not delivery.is_reservable() or delivery.drive_cell == from:
			continue
		var dist := HexUtils.distance(from, delivery.drive_cell)
		if dist < best_dist:
			best_dist = dist
			best = delivery.drive_cell
	return best


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
	if _movement != null:
		_undo_barrier = _movement.path().size()  # a teleport just happened: undo_step() must never pop it
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


## Coup de pouce (boost token — a resource pool, not a one-shot power): spends one of the current
## player's [member Player.boost_tokens] to adjust the current movement's budget by [param delta]
## (new dice total − old), from a reroll or a "fix one die to max". Only usable before the turn's
## first step ("après ton lancer, avant de partir") — [method TurnMovement.path] starts at size 1
## (the start cell only); anything more means a step was already taken.
func spend_boost_token(delta: int) -> bool:
	if _context == null or _subphase != SubPhase.DEPLACEMENT or _movement == null:
		return false
	if _movement.path().size() > 1:
		return false
	var player := current_player()
	if player.boost_tokens <= 0:
		return false
	if delta >= 0:
		_movement.add_steps(delta)
	else:
		_movement.subtract_steps(-delta)
	player.boost_tokens -= 1
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
	if _check_delivery_transitions() and _movement != null:
		_undo_barrier = _movement.path().size()  # reserving jumped straight to EN_COURS: same barrier as a pickup
	return true


# Drives automatic transitions from the current pawn position; called after each step and after a
# reservation. RESERVE -> EN_COURS on the drive cell; EN_COURS -> delivery on the recipient cell.
# Returns true if any transition fired (the caller may need to move the undo barrier past it).
func _check_delivery_transitions() -> bool:
	var cell := position_of(current_player())
	var transitioned := false
	for delivery in deliveries_in_flight(_current):
		if delivery.status == DeliveryStatus.Kind.RESERVE and cell == delivery.drive_cell:
			delivery.status = DeliveryStatus.Kind.EN_COURS
			delivery_in_progress.emit(delivery)
			transitioned = true
		elif delivery.status == DeliveryStatus.Kind.EN_COURS and cell == delivery.recipient_cell:
			_complete_delivery(delivery)
			transitioned = true
	if _context != null:
		_context.current_delivery = _primary_delivery(_current)
	return transitioned


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
