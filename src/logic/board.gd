class_name Board
extends RefCounted
## The board model: which axial cells are occupied, by which block, and the placement rules.
##
## Pure logic — no nodes, no rendering. The view layer listens to [signal changed] and reads
## [method get_cells] to draw. Designed so a future A* layer can walk the occupied cells as a
## graph via [method occupied_cells] / [method is_occupied].

## Emitted whenever the set of occupied cells changes (after a successful placement).
signal changed

# Maps an axial cell (Vector2i) to the StringName id of the block that occupies it.
var _cells: Dictionary = {}


## True while no block has been placed yet.
func is_empty() -> bool:
	return _cells.is_empty()


## True if [param cell] is already taken.
func is_occupied(cell: Vector2i) -> bool:
	return _cells.has(cell)


## All occupied cells.
func occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _cells:
		result.append(cell)
	return result


## A copy of the cell -> block-id map, for rendering and pathfinding.
func get_cells() -> Dictionary:
	return _cells.duplicate()


## Whether [param block] can legally be placed at [param anchor]/[param rotation]:
## no overlap, and (unless the board is empty) at least one new cell touches an existing one.
func can_place(block: BlockDefinition, anchor: Vector2i, rotation: int) -> bool:
	var target := block.get_cells(anchor, rotation)
	for cell in target:
		if is_occupied(cell):
			return false
	if is_empty():
		return true
	return _touches_existing(target)


## Places [param block] if legal. Returns true on success and emits [signal changed].
func place(block: BlockDefinition, anchor: Vector2i, rotation: int) -> bool:
	if not can_place(block, anchor, rotation):
		return false
	for cell in block.get_cells(anchor, rotation):
		_cells[cell] = block.id
	changed.emit()
	return true


# True when any cell in [param target] is adjacent to an already-occupied cell.
func _touches_existing(target: Array[Vector2i]) -> bool:
	for cell in target:
		for neighbor in HexUtils.neighbors(cell):
			if is_occupied(neighbor):
				return true
	return false
