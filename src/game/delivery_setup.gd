class_name DeliverySetup
extends RefCounted
## Builds the deliveries once the board is assembled, with RANDOM placement under per-tile quotas:
## **1 drive per tile** (a random reachable URBAN cell) and **1 recipient per tile** (a random reachable
## GREEN cell). The drives and recipients are then paired 1-to-1 in a SHUFFLED order, so a delivery's
## recipient is not necessarily on its drive's tile (mono- or bi-tile at random). Pure & static; the RNG
## is injected for deterministic tests.
##
## REACHABILITY (critical): [TurnMovement.step] only advances onto a *walkable neighbour*, so we only
## pick cells adjacent to the road network, and we pair each drive with a *reachable* recipient —
## otherwise a delivery could never be completed and [member GamePhase.is_finished] would never hold.
##
## Tile order convention: [member Delivery.tiles] is [drive_tile] (mono) or [drive_tile, recipient_tile]
## (bi) — drive first — matching [Delivery]'s owners and the reservation check in [GamePhase]. Identities
## (enseigne + destinataire) are assigned per delivery by [GameRoot] via [DeliveryGenerator].


## Returns up to [param max_count] deliveries (cells only): one drive + one recipient per tile, paired
## 1-to-1 in random order (cross-tile). [param excluded] cells are kept out of the recipient pool (e.g.
## player start cells).
static func build(board: Board, rng: RandomNumberGenerator, max_count: int = -1, excluded: Dictionary = {}) -> Array[Delivery]:
	var walkable := RoadNetwork.walkable_from_board(board)
	var drives: Array[Vector2i] = []      # one per tile
	var recipients: Array[Vector2i] = []  # one per tile
	for piece in board.pieces():
		drives.append_array(_pick_reachable(piece, CellType.Kind.URBAN, walkable, rng, 1, {}))
		recipients.append_array(_pick_reachable(piece, CellType.Kind.GREEN, walkable, rng, 1, excluded))
	if drives.is_empty() or recipients.is_empty():
		return []
	# Every chosen drive/recipient cell becomes walkable during a turn → treat all as passable 'extra'.
	var extra := {}
	for cell in drives:
		extra[cell] = true
	for cell in recipients:
		extra[cell] = true
	_shuffle(drives, rng)
	_shuffle(recipients, rng)

	var count := mini(drives.size(), recipients.size())
	if max_count >= 0:
		count = mini(count, max_count)
	var pool := recipients.duplicate()
	var deliveries: Array[Delivery] = []
	for drive in drives:
		if deliveries.size() >= count:
			break
		# Pair with the first remaining recipient reachable from this drive (board is connected, so the
		# shuffled order yields a random cross-tile pairing).
		var picked := -1
		for k in pool.size():
			if RoadNetwork.is_reachable(walkable, drive, pool[k], extra):
				picked = k
				break
		if picked < 0:
			continue
		var recipient: Vector2i = pool[picked]
		pool.remove_at(picked)
		var drive_piece := board.piece_at(drive)
		var recipient_piece := board.piece_at(recipient)
		var tiles: Array[PlacedPiece] = [drive_piece]
		if recipient_piece != drive_piece:
			tiles.append(recipient_piece)
		deliveries.append(Delivery.new(drive, recipient, tiles))
	return deliveries


# Up to [param count] cells of [param piece] of terrain [param kind] adjacent to a [param walkable]
# cell (so steppable from the network), excluding [param excluded], picked at random (shuffled).
static func _pick_reachable(piece: PlacedPiece, kind: int, walkable: Dictionary, rng: RandomNumberGenerator, count: int, excluded: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for tc in piece.typed_cells:
		if tc["type"] != kind:
			continue
		var cell: Vector2i = tc["cell"]
		if excluded.has(cell):
			continue
		for neighbor in HexUtils.neighbors(cell):
			if walkable.has(neighbor):
				cells.append(cell)
				break
	_shuffle(cells, rng)
	return cells.slice(0, count)


# Seeded Fisher-Yates shuffle in place (same pattern as SetupDistributor).
static func _shuffle(cells: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
