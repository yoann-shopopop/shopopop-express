class_name TourneeSession
extends Node
## Orchestrates the solo "La Tournée" score-attack session on top of the SAME GamePhase/GameRoot used
## for real play: 16 rounds (a "journée" from 8h to 20h — see [method clock_text]), a named chaining
## bonus (+5 the moment a SECOND delivery completes within the same round — the mini-TSP of grouping
## pickups is the whole point of the cotransporteur job), and a "score du collègue" ghost —
## [method compute_ghost_score] runs AutoPilot on the same board/starting deliveries in a quick
## headless pass BEFORE the session starts, so the player has something concrete to beat. Bronze/
## Argent/Or thresholds were calibrated once offline (`tools/calibrate_tournee.gd`, 200 samples,
## 2026-07-16: p25=170, p50=245, p75=300) and are hardcoded below; recalibrate and update these
## constants after any scoring/board change.

## A new round began (fires from GamePhase.turn_changed — with a single player, every turn wraps).
signal round_advanced(round_number: int, rounds_left: int)
## The chaining bonus was just awarded (once per round, at the 2nd completion in that round).
signal chain_bonus_awarded(total_chain_bonus: int)
## The day is over (16 rounds elapsed, or no delivery left) — [param result] is a Dictionary:
## { score, base_score, chain_bonus, ghost_score, tier, beat_ghost }.
signal session_finished(result: Dictionary)

const MAX_ROUNDS := 16
const CHAIN_BONUS := 5
const BRONZE := 150
const ARGENT := 225
const OR := 300

var _phase: GamePhase
var _chain_bonus_total := 0
var _last_completion_round := -1
var _completions_this_round := 0
var _ghost_score := 0
var _ended := false


## Wires the session to [param phase] (GameRoot's own) and [param ghost_score] — precomputed via
## [method compute_ghost_score] on the SAME board/starting deliveries before the session starts.
func start(phase: GamePhase, ghost_score: int) -> void:
	_phase = phase
	_ghost_score = ghost_score
	_phase.delivery_completed.connect(_on_delivery_completed)
	_phase.turn_changed.connect(_on_turn_changed)


## The current round (1-based).
func current_round() -> int:
	return _phase.round_number()


## How many rounds remain before the day ends (0 once the last round is being played).
func rounds_left() -> int:
	return maxi(0, MAX_ROUNDS - _phase.round_number() + 1)


## A cosmetic clock: "8h00" at round 1 up to "20h00" at round MAX_ROUNDS (12h spread over 16 rounds).
func clock_text() -> String:
	var minutes_per_round := (12 * 60) / MAX_ROUNDS
	var total_minutes := 8 * 60 + (current_round() - 1) * minutes_per_round
	return "%dh%02d" % [total_minutes / 60, total_minutes % 60]


## Total score including the chaining bonus (the base delivery score itself lives in GamePhase).
func total_score() -> int:
	return _phase.score_of(_phase.current_player()) + _chain_bonus_total


func chain_bonus_total() -> int:
	return _chain_bonus_total


func ghost_score() -> int:
	return _ghost_score


## "Bronze"/"Argent"/"Or"/"" (below Bronze) for [param score] — see the calibration note above.
static func tier_for(score: int) -> String:
	# TranslationServer.translate, not tr(): this is a static method, no Object instance to call tr() on.
	if score >= OR:
		return TranslationServer.translate("Or")
	if score >= ARGENT:
		return TranslationServer.translate("Argent")
	if score >= BRONZE:
		return TranslationServer.translate("Bronze")
	return ""


func _on_delivery_completed(_delivery: Delivery, _points: int) -> void:
	if _ended:
		return
	var round := _phase.round_number()
	if round == _last_completion_round:
		_completions_this_round += 1
		if _completions_this_round == 2:
			_chain_bonus_total += CHAIN_BONUS
			chain_bonus_awarded.emit(_chain_bonus_total)
	else:
		_last_completion_round = round
		_completions_this_round = 1
	if _phase.is_finished():
		_finish()


func _on_turn_changed(_player: Player) -> void:
	if _ended:
		return
	round_advanced.emit(_phase.round_number(), rounds_left())
	if _phase.round_number() > MAX_ROUNDS:
		_finish()


func _finish() -> void:
	if _ended:
		return
	_ended = true
	var score := total_score()
	session_finished.emit({
		"score": score,
		"base_score": _phase.score_of(_phase.current_player()),
		"chain_bonus": _chain_bonus_total,
		"ghost_score": _ghost_score,
		"tier": tier_for(score),
		"beat_ghost": score > _ghost_score,
	})


## Simulates a full (up to) 16-round AutoPilot playthrough of the SAME scenario — [param board]
## shared as-is (read-only from GamePhase's perspective), [param real_deliveries] cloned with the
## same initial drive/recipient cells and enseigne/destinataire so it's the same starting
## arrangement. The recycling pool afterward is independently shuffled (a documented simplification,
## not a bit-for-bit replay of the real session's RNG) — the "score du collègue" to beat. Pure; call
## once before the real session starts (e.g. right after GameRoot.setup()).
static func compute_ghost_score(
	board: Board,
	real_player: Player,
	real_deliveries: Array[Delivery],
	enseignes: Array[EnseigneDefinition],
	destinataires: Array[DestinataireDefinition],
	events: Array[CardDefinition],
	rng: RandomNumberGenerator,
) -> int:
	var ghost_player := Player.new(real_player.color)
	ghost_player.index = 0
	ghost_player.start_block = real_player.start_block
	ghost_player.start_cell = real_player.start_cell
	var ghost_deliveries: Array[Delivery] = []
	for d in real_deliveries:
		var clone := Delivery.new(d.drive_cell, d.recipient_cell, d.tiles)
		clone.enseigne = d.enseigne
		clone.destinataire = d.destinataire
		ghost_deliveries.append(clone)
	# slots = ghost_deliveries.size() only so the generator's internal _combos array is large enough
	# for GamePhase._complete_delivery's recycle(idx) calls to stay in bounds — its own initial pairing
	# is discarded (ghost_deliveries were already assigned above), at the minor cost of drawing (and
	# thus removing from the pool) that many destinataires it never actually uses.
	var generator := DeliveryGenerator.new(enseignes, destinataires, ghost_deliveries.size(), rng, -1)
	var phase := GamePhase.new([ghost_player] as Array[Player], board, ghost_deliveries, generator)
	var dice := DiceRoller.new(rng)
	var deck := Deck.new(events, rng)
	deck.shuffle()
	for _round in MAX_ROUNDS:
		if phase.is_finished():
			break
		AutoPilot.play_turn(phase, board, ghost_deliveries, dice, deck)
	return phase.score_of(ghost_player)
