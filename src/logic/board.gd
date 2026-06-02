class_name Board
extends RefCounted
## The board model: which axial cells are occupied, by which piece/owner/type, and the placement
## rules. Pure logic — no nodes. The view listens to [signal changed] and reads [method pieces].
##
## Adjacency rule ("road touches road"): a new piece connects if one of its connector cells is a
## hex-neighbor of a connector cell already on the board. Hexagon connectors are road edge-centers;
## bridge connectors are its end cells. Designed so a future A* can walk roads via the cell index.

## Emitted whenever the set of placed pieces changes (after a successful placement).
signal changed

var _pieces: Array[PlacedPiece] = []
var _index: Dictionary = {}            # Vector2i cell -> { "type": int, "owner": int, "piece": PlacedPiece }
var _connectors: Dictionary = {}       # Vector2i cell -> true (all connector cells on the board)


## True while no piece has been placed yet.
func is_empty() -> bool:
	return _pieces.is_empty()


## True if [param cell] is already taken.
func is_occupied(cell: Vector2i) -> bool:
	return _index.has(cell)


## Terrain type at [param cell] ([enum CellType.Kind]), or -1 if empty.
func cell_type_at(cell: Vector2i) -> int:
	return _index[cell]["type"] if _index.has(cell) else -1


## Owner at [param cell] (PlayerColor.Kind), or -1 if empty/unowned.
func owner_at(cell: Vector2i) -> int:
	return _index[cell]["owner"] if _index.has(cell) else -1


## All placed pieces, in placement order.
func pieces() -> Array[PlacedPiece]:
	return _pieces


## All occupied cells.
func occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _index:
		result.append(cell)
	return result


## All connector (road-link) cells currently on the board.
func connector_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _connectors:
		result.append(cell)
	return result


## Whether [param block] can be placed at [param anchor]/[param rotation]: no overlap, and (unless
## the board is empty) at least one of its connectors is adjacent to an existing connector.
func can_place(block: BlockDefinition, anchor: Vector2i, rotation: int) -> bool:
	for cell in block.get_cells(anchor, rotation):
		if is_occupied(cell):
			return false
	if is_empty():
		return true
	return _connects(block.get_connectors(anchor, rotation))


## Places [param block] for [param owner] if legal. Returns true and emits [signal changed].
func place(block: BlockDefinition, anchor: Vector2i, rotation: int, owner: int = -1) -> bool:
	if not can_place(block, anchor, rotation):
		return false
	var piece := PlacedPiece.new(block, anchor, rotation, owner)
	for tc in piece.typed_cells:
		_index[tc["cell"]] = {"type": tc["type"], "owner": owner, "piece": piece}
	for c in piece.connector_cells:
		_connectors[c] = true
	_pieces.append(piece)
	changed.emit()
	return true


# True when any of [param target_connectors] is a hex-neighbor of an existing connector cell.
func _connects(target_connectors: Array[Vector2i]) -> bool:
	for c in target_connectors:
		for neighbor in HexUtils.neighbors(c):
			if _connectors.has(neighbor):
				return true
	return false
