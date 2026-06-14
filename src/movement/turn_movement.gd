class_name TurnMovement
extends RefCounted
## A board walk for a single turn over an injected set of walkable cells.
##
## Unlike [Movement] (a self-avoiding walk of fixed length, used by the standalone demo), this is the
## real in-game walk: revisiting cells is allowed (back-tracking, loops), the budget can be adjusted
## mid-turn ([method add_steps]/[method subtract_steps], for event cards and the +1 pickup cost), and
## [method teleport_to] can reposition the pawn onto any cell (even non-walkable, e.g. a drive)
## without spending budget — required by the teleport event cards. Pure logic — no Board/Pawn/render.

## Emitted after each successful [method step].
signal moved(to: Vector2i)
## Emitted whenever the remaining budget changes (step, add, subtract).
signal step_budget_changed(remaining: int)
## Emitted once the movement finishes (budget spent or stuck).
signal finished

var _walkable: Dictionary
var _current: Vector2i
var _remaining: int
var _path: Array[Vector2i] = []


func _init(walkable: Dictionary, start: Vector2i, budget: int) -> void:
	assert(budget >= 0, "budget cannot be negative")
	_walkable = walkable
	_current = start
	_remaining = budget
	_path.append(start)


## The cell the walk currently sits on.
func current() -> Vector2i:
	return _current


## Steps still to spend.
func remaining() -> int:
	return _remaining


## The full route walked so far, starting with the start cell.
func path() -> Array[Vector2i]:
	return _path.duplicate()


## Walkable neighbors of the current cell (revisiting allowed) — empty once the budget is spent.
func legal_moves() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _remaining <= 0:
		return result
	for neighbor in HexUtils.neighbors(_current):
		if _walkable.has(neighbor):
			result.append(neighbor)
	return result


## Advances onto [param cell] if it is a legal move. Returns false otherwise.
func step(cell: Vector2i) -> bool:
	if not legal_moves().has(cell):
		return false
	_current = cell
	_remaining -= 1
	_path.append(cell)
	moved.emit(cell)
	step_budget_changed.emit(_remaining)
	if is_finished():
		finished.emit()
	return true


## Grants [param n] extra steps this turn (event bonuses, e.g. Grand Soleil +3).
func add_steps(n: int) -> void:
	_remaining += n
	step_budget_changed.emit(_remaining)


## Removes [param n] steps (event maluses, the +1 pickup cost), clamped at zero.
func subtract_steps(n: int) -> void:
	_remaining = max(0, _remaining - n)
	step_budget_changed.emit(_remaining)


## Adds [param cells] to the walkable set for the rest of this turn — used by Passage Secret (Gégé),
## which makes water passable. A no-op for cells already walkable.
func allow_cells(cells: Dictionary) -> void:
	for cell in cells:
		_walkable[cell] = true


## Repositions the pawn onto [param cell] without spending budget and without an adjacency or
## walkable check — for teleport event cards (Faille Spatio-Temporelle, Escorte Policière, returns).
func teleport_to(cell: Vector2i) -> void:
	_current = cell
	_path.append(cell)
	moved.emit(cell)


## The whole budget has been spent.
func is_complete() -> bool:
	return _remaining == 0


## Budget remains but no walkable neighbor exists — a forced stop on a dead-end.
func is_stuck() -> bool:
	return _remaining > 0 and legal_moves().is_empty()


## The movement is over, whether complete or stuck.
func is_finished() -> bool:
	return is_complete() or is_stuck()
