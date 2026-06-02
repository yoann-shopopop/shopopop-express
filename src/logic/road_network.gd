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
