extends SceneTree
## Headless reliability soak: plays full auto-piloted games for every player count (2..4, the V1
## table) over many seeds, asserting each one reaches GamePhase.is_finished() within a turn cap
## (i.e. no softlock and every parcel deliverable). Run with:
##   godot --headless --path . -s res://tools/soak_test.gd
## Exits 0 on success, 1 if any game stalled or a board could not be assembled.

const ENSEIGNES_DIR := "res://resources/enseignes/"
const DESTINATAIRES_DIR := "res://resources/destinataires/"
const EVENTS_DIR := "res://resources/events/"
const SEEDS_PER_COUNT := 10
const TURN_CAP := 6000


func _init() -> void:
	var enseignes: Array[EnseigneDefinition] = []
	for e in _load_dir(ENSEIGNES_DIR):
		enseignes.append(e)
	var destinataires: Array[DestinataireDefinition] = []
	for d in _load_dir(DESTINATAIRES_DIR):
		destinataires.append(d)
	var event_defs: Array[CardDefinition] = []
	for c in _load_dir(EVENTS_DIR):
		event_defs.append(c)

	var failures := 0
	var games := 0
	for count in range(2, 5):  # 2-4 players: the V1 configurations offered by the UI
		for s in range(SEEDS_PER_COUNT):
			games += 1
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%d-%d" % [count, s])
			var built := AutoBoard.build(count, rng)
			if not built["ok"]:
				printerr("PLACEMENT FAILED  count=%d seed=%d" % [count, s])
				failures += 1
				continue
			var board: Board = built["board"]
			var players: Array = built["players"]
			var deliveries := DeliverySetup.build(board, rng, destinataires.size())
			# Same rule as GameRoot: total deliveries = number of placed tiles (capped identity pool).
			var generator := DeliveryGenerator.new(
				enseignes, destinataires, deliveries.size(), rng, deliveries.size())
			var combos := generator.combos()
			for i in deliveries.size():
				if i < combos.size():
					deliveries[i].enseigne = combos[i].enseigne
					deliveries[i].destinataire = combos[i].destinataire
			var typed_players: Array[Player] = []
			for p in players:
				typed_players.append(p)
			var phase := GamePhase.new(typed_players, board, deliveries, generator)
			var dice := DiceRoller.new(rng)
			var events := Deck.new(event_defs, rng)
			events.shuffle()

			var turns := 0
			while not phase.is_finished() and turns < TURN_CAP:
				turns += 1
				AutoPilot.play_turn(phase, board, deliveries, dice, events)

			if not phase.is_finished():
				printerr("SOFTLOCK  count=%d seed=%d turns=%d remaining=%d deliveries=%d" % [
					count, s, turns, phase.deliveries_remaining(), deliveries.size()])
				failures += 1
			else:
				print("OK  count=%d seed=%d turns=%d deliveries=%d total=%d" % [
					count, s, turns, deliveries.size(), _total(phase, players)])

	print("---- soak done: %d games, %d failures ----" % [games, failures])
	quit(1 if failures > 0 else 0)


func _total(phase: GamePhase, players: Array) -> int:
	var sum := 0
	for p in players:
		sum += phase.score_of(p)
	return sum


func _load_dir(path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(path + file))
	return result
