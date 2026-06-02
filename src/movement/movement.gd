class_name Movement
extends RefCounted
## A self-avoiding walk of a fixed length over an injected set of walkable cells.
##
## Pure logic — no [Board], no [Pawn], no rendering. Adjacency comes from [HexUtils]; the walkable
## set is injected (a [code]cell -> true[/code] dictionary), so this is testable in isolation and
## decoupled from how the board is built.
##
## Rules: the full budget MUST be spent — there is no voluntary stop, the consumer steps until
## [method is_finished]. Revisiting a cell already walked during this movement (the start included)
## is forbidden. If no legal continuation remains, the movement ends with budget to spare
## ([method is_stuck]); the leftover is lost.

## Emitted after each successful [method step].
signal moved(to: Vector2i)
## Emitted once the movement finishes (budget spent or stuck).
signal finished

var _walkable: Dictionary
var _current: Vector2i
var _remaining: int
var _visited: Dictionary = {}
var _path: Array[Vector2i] = []


func _init(walkable: Dictionary, start: Vector2i, budget: int) -> void:
	assert(budget >= 0, "budget cannot be negative")
	assert(walkable.has(start), "the start cell must be walkable")
	_walkable = walkable
	_current = start
	_remaining = budget
	_visited[start] = true
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


## Walkable, not-yet-visited neighbors of the current cell — empty once the budget is spent.
func legal_moves() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _remaining <= 0:
		return result
	for neighbor in HexUtils.neighbors(_current):
		if _walkable.has(neighbor) and not _visited.has(neighbor):
			result.append(neighbor)
	return result


## Advances onto [param cell] if it is a legal move. Returns false otherwise.
func step(cell: Vector2i) -> bool:
	if not legal_moves().has(cell):
		return false
	_current = cell
	_remaining -= 1
	_visited[cell] = true
	_path.append(cell)
	moved.emit(cell)
	if is_finished():
		finished.emit()
	return true


## The whole budget has been spent.
func is_complete() -> bool:
	return _remaining == 0


## Budget remains but no legal move exists — a forced stop.
func is_stuck() -> bool:
	return _remaining > 0 and legal_moves().is_empty()


## The movement is over, whether complete or stuck.
func is_finished() -> bool:
	return is_complete() or is_stuck()
