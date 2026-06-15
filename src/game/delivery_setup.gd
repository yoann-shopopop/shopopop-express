class_name DeliverySetup
extends RefCounted
## Builds the deliveries once the board is assembled, with RANDOM placement: each delivery pairs a
## drive (any URBAN cell) with a recipient (any GREEN cell) drawn from board-wide pools — so a drive
## and its recipient may sit on DIFFERENT tiles (mono- or bi-tile at random). Pure & static; the RNG is
## injected for deterministic tests.
##
## REACHABILITY (critical): [TurnMovement.step] only advances onto a *walkable neighbour*, and the
## turn's walkable set is roads + events + every delivery's drive/recipient cell. So we only pick cells
## adjacent to the road network, and we verify each drive→recipient pair is actually reachable —
## otherwise a delivery could never be completed and [member GamePhase.is_finished] would never hold.
##
## Tile order convention: [member Delivery.tiles] is [drive_tile] (mono) or [drive_tile, recipient_tile]
## (bi) — drive first — matching [method Delivery.drive_tile_owner]/[method Delivery.recipient_tile_owner]
## and the reservation check in [GamePhase] (reserve on the drive's tile).


## Returns up to [param max_count] random deliveries (all of them when [param max_count] < 0). Drives
## come from URBAN cells, recipients from GREEN cells, both reachable from the road network; cells in
## [param excluded] are kept out of the recipient pool (e.g. player start cells).
static func build(board: Board, rng: RandomNumberGenerator, max_count: int = -1, excluded: Dictionary = {}) -> Array[Delivery]:
	var walkable := RoadNetwork.walkable_from_board(board)
	var drives := _reachable_cells(board, CellType.Kind.URBAN, walkable, {})
	var recipients := _reachable_cells(board, CellType.Kind.GREEN, walkable, excluded)
	_shuffle(drives, rng)
	_shuffle(recipients, rng)
	# Every chosen drive/recipient cell becomes walkable during a turn, so treat all candidates as
	# passable 'extra' when checking that a pair is mutually reachable.
	var extra := {}
	for cell in drives:
		extra[cell] = true
	for cell in recipients:
		extra[cell] = true

	var target := mini(drives.size(), recipients.size())
	if max_count >= 0:
		target = mini(target, max_count)
	var deliveries: Array[Delivery] = []
	var di := 0
	var ri := 0
	while deliveries.size() < target and di < drives.size() and ri < recipients.size():
		var drive: Vector2i = drives[di]
		var recipient: Vector2i = recipients[ri]
		if not RoadNetwork.is_reachable(walkable, drive, recipient, extra):
			ri += 1  # unreachable pair (rare on a connected board): try the next recipient
			continue
		var drive_piece := board.piece_at(drive)
		var recipient_piece := board.piece_at(recipient)
		var tiles: Array[PlacedPiece] = [drive_piece]
		if recipient_piece != drive_piece:
			tiles.append(recipient_piece)
		deliveries.append(Delivery.new(drive, recipient, tiles))
		di += 1
		ri += 1
	return deliveries


# All cells of [param board] of terrain [param kind] adjacent to a [param walkable] cell (hence
# steppable onto from the network), minus any cell in [param excluded].
static func _reachable_cells(board: Board, kind: int, walkable: Dictionary, excluded: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in board.cells_of_type(kind):
		if excluded.has(cell):
			continue
		for neighbor in HexUtils.neighbors(cell):
			if walkable.has(neighbor):
				cells.append(cell)
				break
	return cells


# Seeded Fisher-Yates shuffle in place (same pattern as SetupDistributor).
static func _shuffle(cells: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
