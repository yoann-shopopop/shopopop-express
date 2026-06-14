class_name DiceRoller
extends RefCounted
## Rolls X six-sided dice and records the result until it is consumed.
##
## Pure logic and the authoritative source of dice values (the 3D view only reflects them). The RNG
## is injectable so rolls can be made deterministic in tests; in play, a randomized one is used.

const SIDES := 6

## Emitted on each [method roll], with the values rolled.
signal rolled(values: Array)
## Emitted when the recorded result is taken via [method consume].
signal consumed

var _rng: RandomNumberGenerator
var _last: Array[int] = []


func _init(rng: RandomNumberGenerator = null) -> void:
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()


## Rolls [param count] dice, records the result, and returns the values (each in 1..6).
func roll(count: int) -> Array[int]:
	assert(count >= 0, "cannot roll a negative number of dice")
	var values: Array[int] = []
	for _i in count:
		values.append(_rng.randi_range(1, SIDES))
	_last = values
	rolled.emit(values)
	return values


## A copy of the last roll's values.
func values() -> Array[int]:
	return _last.duplicate()


## Sum of the last roll (0 when there is no result).
func total() -> int:
	var sum := 0
	for v in _last:
		sum += v
	return sum


## Number of dice in the last roll.
func count() -> int:
	return _last.size()


## Re-rolls a single die [param index] of the last roll and returns its new value (1..6), updating the
## recorded result. For Coup d'Accélérateur (Vic). Returns 0 if the index is out of range.
func reroll(index: int) -> int:
	if index < 0 or index >= _last.size():
		return 0
	_last[index] = _rng.randi_range(1, SIDES)
	rolled.emit(_last)
	return _last[index]


## Whether a result is currently recorded.
func has_result() -> bool:
	return not _last.is_empty()


## Takes the recorded result (returns it and clears it) — for a one-off use such as a move budget.
func consume() -> Array[int]:
	var taken := _last.duplicate()
	_last = []
	consumed.emit()
	return taken


## Clears the recorded result without returning it.
func clear() -> void:
	_last = []
