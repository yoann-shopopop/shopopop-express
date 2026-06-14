class_name RoadNetwork
extends RefCounted
## Derives the walkable set (roads + event cells) from a [Board]. Pure, static helpers: the
## [Movement]/[TurnMovement] logic takes a [code]Dictionary[/code] of cell -> true praticable cells.


## Every road or event cell of [param board], as a set [code]{ Vector2i: true }[/code].
static func walkable_from_board(board: Board) -> Dictionary:
	var walkable := {}
	for cell in board.cells_of_type(CellType.Kind.ROUTE):
		walkable[cell] = true
	for cell in board.cells_of_type(CellType.Kind.EVENT):
		walkable[cell] = true
	return walkable


## Like [method walkable_from_board] but with [param closed] cells removed — used by events that
## block a route or close bridges for a turn.
static func walkable_excluding(board: Board, closed: Dictionary) -> Dictionary:
	var walkable := walkable_from_board(board)
	for cell in closed:
		walkable.erase(cell)
	return walkable


## Breadth-first hop-distances from [param start] over [param walkable] (hex 6-neighbours), as
## [code]{ Vector2i: int }[/code]. [param extra] cells are treated as walkable too (a turn's drive /
## recipient destinations sit off the road but must be reachable). [param start] is always included at
## distance 0, even if not itself walkable. Pure; used for reachability checks and trajectory steering.
static func distances_from(walkable: Dictionary, start: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var dist := {start: 0}
	var frontier: Array[Vector2i] = [start]
	var head := 0
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		var next_d: int = dist[cell] + 1
		for neighbor in HexUtils.neighbors(cell):
			if dist.has(neighbor):
				continue
			if walkable.has(neighbor) or extra.has(neighbor):
				dist[neighbor] = next_d
				frontier.append(neighbor)
	return dist


## True if [param target] is reachable from [param start] across [param walkable] (plus [param extra]).
static func is_reachable(walkable: Dictionary, start: Vector2i, target: Vector2i, extra: Dictionary = {}) -> bool:
	if start == target:
		return true
	return distances_from(walkable, start, extra).has(target)
