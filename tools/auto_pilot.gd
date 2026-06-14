class_name AutoPilot
extends RefCounted
## Dev/test helper: plays a turn for the current player with a greedy, BFS-steered strategy — roll,
## walk toward the most useful delivery target (complete an in-flight one, else go pick up the nearest
## available one), reserving on the way, resolving any event drawn. Used by the headless soak test (to
## prove the loop always terminates) and the screenshot harness (to drive a real-looking game). Pure
## logic — it drives the public API of [GamePhase] only.

const SP := GamePhase.SubPhase


## Plays one full turn (planning -> movement -> end) for the current player of [param phase].
## [param board]/[param deliveries] let it path toward targets; [param dice] supplies the budget;
## [param events] resolves rainbow events.
static func play_turn(phase: GamePhase, board: Board, deliveries: Array, dice: DiceRoller, events: Deck) -> void:
	if phase.current_subphase() != SP.PLANIFICATION:
		return
	var player := phase.current_player()
	var dice_count := 2
	if player.character != null:
		dice_count = player.character.dice_count()
	dice.roll(dice_count)
	phase.begin_movement(dice.total())
	var safety := 0
	while phase.movement() != null and phase.current_subphase() == SP.DEPLACEMENT \
			and phase.movement().remaining() > 0:
		safety += 1
		if safety > 400:
			break
		phase.reserve_delivery()  # no-op when nothing reservable on this tile
		var target = _choose_target(phase, deliveries)
		var next = _step_toward(phase, board, deliveries, target)
		if next == null:
			break
		if not phase.try_step(next):
			break
		if phase.current_subphase() == SP.EVENEMENT:
			_auto_event(phase, events)
	phase.end_turn()


# The most useful cell to walk toward: finish an EN_COURS parcel (its recipient), then a RESERVE one
# (its drive), else go pick up the nearest still-available delivery (its drive). null if none left.
static func _choose_target(phase: GamePhase, _deliveries: Array):
	var player := phase.current_player()
	var held := phase.deliveries_in_flight(player.index)
	for d in held:
		if d.status == DeliveryStatus.Kind.EN_COURS:
			return d.recipient_cell
	for d in held:
		if d.status == DeliveryStatus.Kind.RESERVE:
			return d.drive_cell
	var from := phase.position_of(player)
	var best = null
	var best_dist := 1 << 30
	for d in phase.available_deliveries():
		var dist := HexUtils.distance(from, d.drive_cell)
		if dist < best_dist:
			best_dist = dist
			best = d.drive_cell
	return best


# Picks the legal move that gets closest to [param target] (BFS distance over the turn's walkable set,
# which includes every delivery's off-road drive/recipient cells). Falls back to any legal move.
static func _step_toward(phase: GamePhase, board: Board, deliveries: Array, target):
	var moves := phase.movement().legal_moves()
	if moves.is_empty():
		return null
	if target == null:
		return moves[0]
	var walkable := RoadNetwork.walkable_from_board(board)
	var extra := {}
	for d in deliveries:
		extra[d.drive_cell] = true
		extra[d.recipient_cell] = true
	var dist := RoadNetwork.distances_from(walkable, target, extra)
	var best = null
	var best_dist := 1 << 30
	for m in moves:
		var dd: int = dist.get(m, 1 << 29)
		if dd < best_dist:
			best_dist = dd
			best = m
	return best if best != null else moves[0]


# Draws one event card and applies it (reshuffling if the deck ran dry), then discards it.
static func _auto_event(phase: GamePhase, events: Deck) -> void:
	var drawn := events.draw(1)
	if drawn.is_empty():
		events.reshuffle()
		drawn = events.draw(1)
	if drawn.is_empty():
		return
	var card := drawn[0]
	if card is EventCardDefinition:
		phase.apply_event(card)
	events.discard(card)
