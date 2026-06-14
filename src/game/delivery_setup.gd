class_name DeliverySetup
extends RefCounted
## Builds the deliveries once the board is assembled: each placed tile carrying both a road-reachable
## drive (urban cell) and a road-reachable recipient (green cell) yields one single-tile delivery.
## Pieces without both — bridges, or tiles whose urban/green cells are all walled off from the road —
## are skipped. So the number of deliveries equals the number of deliverable tiles posed. Pure & static.
##
## V1 keeps deliveries single-tile (drive + recipient on the same tile); the 1-or-2-tile span and
## manual token placement (rules step 5-6) are a later refinement.
##
## REACHABILITY (critical): [TurnMovement.step] only advances onto a *walkable neighbour*, and the
## turn's walkable set is roads + events + every delivery's drive/recipient cell. A drive/recipient
## buried inside a tile with no road neighbour could therefore never be reached, leaving a delivery
## permanently in flight so [member GamePhase.is_finished] never holds — the game would not end. We
## guard against that here by only ever selecting cells adjacent to the walkable network.


## Returns one [Delivery] per qualifying placed tile of [param board]. A tile qualifies only when it
## has both a road-reachable drive and a road-reachable recipient (so the delivery can be completed).
static func build(board: Board) -> Array[Delivery]:
	var walkable := RoadNetwork.walkable_from_board(board)
	var deliveries: Array[Delivery] = []
	for piece in board.pieces():
		var drive = _reachable_cell_of_type(piece, CellType.Kind.URBAN, walkable)
		if drive == null:
			continue  # no urban cell next to a road: nothing pickable here (e.g. a bridge)
		# The recipient may sit next to its own drive rather than the road — once picked up, the drive
		# cell itself becomes walkable, so accept green cells adjacent to roads OR to the chosen drive.
		var augmented := walkable.duplicate()
		augmented[drive] = true
		var recipient = _reachable_cell_of_type(piece, CellType.Kind.GREEN, augmented)
		if recipient == null:
			continue
		deliveries.append(Delivery.new(drive, recipient, [piece] as Array[PlacedPiece]))
	return deliveries


## The drive (pickup) cell of [param piece]: a road-reachable URBAN cell, or null if none. Single
## source of the "drive cell" rule, shared with the tile rendering (DRIVE storefront art) so the art
## always sits on the same cell the delivery uses. [param board] supplies the road network.
static func drive_cell_of(piece: PlacedPiece, board: Board):
	return _reachable_cell_of_type(piece, CellType.Kind.URBAN, RoadNetwork.walkable_from_board(board))


## The recipient (drop-off) cell of [param piece]: a road-reachable GREEN cell, or null if none.
static func recipient_cell_of(piece: PlacedPiece, board: Board):
	var walkable := RoadNetwork.walkable_from_board(board)
	var drive = _reachable_cell_of_type(piece, CellType.Kind.URBAN, walkable)
	if drive != null:
		walkable[drive] = true
	return _reachable_cell_of_type(piece, CellType.Kind.GREEN, walkable)


# The first absolute cell of [param piece] of terrain [param kind] adjacent to a [param walkable] cell
# — hence steppable onto from the network. null when the piece has no such cell (the caller skips it).
static func _reachable_cell_of_type(piece: PlacedPiece, kind: int, walkable: Dictionary):
	for tc in piece.typed_cells:
		if tc["type"] != kind:
			continue
		for neighbor in HexUtils.neighbors(tc["cell"]):
			if walkable.has(neighbor):
				return tc["cell"]
	return null
