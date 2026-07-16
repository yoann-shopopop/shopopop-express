extends SceneTree
## Calibrates La Tournée's Bronze/Argent/Or score thresholds: runs N solo, auto-piloted 16-round
## sessions (same board-building path as TourneeSession, same greedy AutoPilot) across many seeds,
## and reports score percentiles. Run once offline; the resulting numbers are hardcoded as constants
## in TourneeSession (recalibrate by re-running this after any scoring/board change and updating
## those constants — see CLAUDE.md).
## Run: godot --headless --path . -s res://tools/calibrate_tournee.gd -- <sample_count>
## Defaults: sample_count=200.

const ROUNDS := 16
const ENSEIGNES_DIR := "res://resources/enseignes/"
const DESTINATAIRES_DIR := "res://resources/destinataires/"
const EVENTS_DIR := "res://resources/events/"


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := _script_args()
	var samples: int = int(args[0]) if args.size() > 0 else 200

	var enseignes: Array[EnseigneDefinition] = []
	for e in _load_dir(ENSEIGNES_DIR):
		enseignes.append(e)
	var destinataires: Array[DestinataireDefinition] = []
	for d in _load_dir(DESTINATAIRES_DIR):
		destinataires.append(d)
	var event_defs: Array[CardDefinition] = []
	for c in _load_dir(EVENTS_DIR):
		event_defs.append(c)

	var scores: Array[int] = []
	for s in samples:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("tournee-calibration-%d" % s)
		var built := AutoBoard.build(1, rng)
		if not built["ok"]:
			continue
		var board: Board = built["board"]
		var players: Array = built["players"]
		var typed_players: Array[Player] = []
		for p in players:
			typed_players.append(p)
		# Uncapped pool (max_deliveries=-1): the 16-round session lives on recycling, unlike the
		# normal "total tuiles = livraisons" rule for the competitive mode.
		var deliveries := DeliverySetup.build(board, rng, destinataires.size())
		var generator := DeliveryGenerator.new(enseignes, destinataires, deliveries.size(), rng, -1)
		var combos := generator.combos()
		for i in deliveries.size():
			if i < combos.size():
				deliveries[i].enseigne = combos[i].enseigne
				deliveries[i].destinataire = combos[i].destinataire
		var phase := GamePhase.new(typed_players, board, deliveries, generator)
		var dice := DiceRoller.new(rng)
		var events := Deck.new(event_defs, rng)
		events.shuffle()

		for _round in ROUNDS:
			if phase.is_finished():
				break
			AutoPilot.play_turn(phase, board, deliveries, dice, events)
		scores.append(phase.score_of(typed_players[0]))

	scores.sort()
	if scores.is_empty():
		print("No samples produced a score — check the resource directories.")
		quit(1)
		return
	print("Samples: ", scores.size())
	print("Min/Max: ", scores[0], " / ", scores[scores.size() - 1])
	print("p25: ", _percentile(scores, 0.25))
	print("p50 (médiane): ", _percentile(scores, 0.50))
	print("p75: ", _percentile(scores, 0.75))
	print("p90: ", _percentile(scores, 0.90))
	quit(0)


func _percentile(sorted_scores: Array[int], p: float) -> int:
	var idx := int(round(p * (sorted_scores.size() - 1)))
	return sorted_scores[idx]


func _load_dir(path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(path + file))
	return result


func _script_args() -> PackedStringArray:
	var result := PackedStringArray()
	var seen := false
	for a in OS.get_cmdline_user_args():
		result.append(a)
		seen = true
	if seen:
		return result
	var all := OS.get_cmdline_args()
	var idx := all.find("--")
	if idx >= 0 and idx + 1 < all.size():
		for i in range(idx + 1, all.size()):
			result.append(all[i])
	return result
