class_name DeliverySetup
extends RefCounted
## Builds the deliveries once the board is assembled: each placed tile carrying both a drive (urban
## cell) and a recipient (green cell) yields one single-tile delivery. Pieces without both — bridges —
## are skipped. So the number of deliveries equals the number of tiles posed. Pure & static.
##
## V1 keeps deliveries single-tile (drive + recipient on the same tile); the 1-or-2-tile span and
## manual token placement (rules step 5-6) are a later refinement.


## Returns one [Delivery] per qualifying placed tile of [param board].
static func build(board: Board) -> Array[Delivery]:
	var deliveries: Array[Delivery] = []
	for piece in board.pieces():
		var drive = _first_cell_of_type(piece, CellType.Kind.URBAN)
		var recipient = _first_cell_of_type(piece, CellType.Kind.GREEN)
		if drive == null or recipient == null:
			continue  # not a deliverable tile (e.g. a bridge)
		deliveries.append(Delivery.new(drive, recipient, [piece] as Array[PlacedPiece]))
	return deliveries


# The first absolute cell of [param piece] whose terrain is [param kind], or null if none.
static func _first_cell_of_type(piece: PlacedPiece, kind: int):
	for tc in piece.typed_cells:
		if tc["type"] == kind:
			return tc["cell"]
	return null
