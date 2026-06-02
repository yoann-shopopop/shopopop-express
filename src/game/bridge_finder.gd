class_name BridgeFinder
extends RefCounted
## Finds a bridge placement that connects a block dropped "one cell too far" to the existing road
## network: one bridge end links to the board's roads, the other to the block's roads, with no
## overlap. Returns { "anchor": Vector2i, "rotation": int } or {} if none fits.

const SEARCH := 4  # how far around the block anchor to look for a bridge spot


static func find(board: Board, block: BlockDefinition, anchor: Vector2i, rotation: int, bridge: BlockDefinition) -> Dictionary:
	var block_cells := block.get_cells(anchor, rotation)
	for c in block_cells:
		if board.is_occupied(c):
			return {}  # the block itself overlaps — a bridge can't fix that

	var block_conns := block.get_connectors(anchor, rotation)
	var board_conns := board.connector_cells()
	var blocked := {}
	for c in block_cells:
		blocked[c] = true

	for bq in range(anchor.x - SEARCH, anchor.x + SEARCH + 1):
		for br in range(anchor.y - SEARCH, anchor.y + SEARCH + 1):
			for brot in 6:
				var b_anchor := Vector2i(bq, br)
				if _overlaps(bridge.get_cells(b_anchor, brot), board, blocked):
					continue
				if _links(bridge.get_connectors(b_anchor, brot), block_conns, board_conns):
					return {"anchor": b_anchor, "rotation": brot}
	return {}


static func _overlaps(cells: Array[Vector2i], board: Board, blocked: Dictionary) -> bool:
	for c in cells:
		if board.is_occupied(c) or blocked.has(c):
			return true
	return false


# True if one bridge end is adjacent to the block's roads and the other to the board's roads.
static func _links(bridge_conns: Array[Vector2i], block_conns: Array[Vector2i], board_conns: Array[Vector2i]) -> bool:
	for i in bridge_conns.size():
		var other := bridge_conns[(i + 1) % bridge_conns.size()]
		if _adjacent_to_any(bridge_conns[i], block_conns) and _adjacent_to_any(other, board_conns):
			return true
	return false


static func _adjacent_to_any(cell: Vector2i, targets: Array[Vector2i]) -> bool:
	for t in targets:
		if HexUtils.are_adjacent(cell, t):
			return true
	return false
