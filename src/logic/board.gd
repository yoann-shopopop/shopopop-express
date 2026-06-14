class_name Board
extends RefCounted
## The board model: which axial cells are occupied, by which piece/owner/type, and the placement
## rules. Pure logic — no nodes. The view listens to [signal changed] and reads [method pieces].
##
## Connection model. Two kinds of connector cells:
##  - ROAD connectors: a block's road edge-centers (a road cell).
##  - BRIDGE-END connectors: a placed bridge's water ends (where its road crosses to/from a road).
## Rules: a BRIDGE may only attach to a ROAD connector (never to water / another bridge end). A
## BLOCK may attach to a ROAD connector OR a BRIDGE-END (so a road can continue across a bridge).

## Emitted whenever the set of placed pieces changes (after a successful placement).
signal changed

var _pieces: Array[PlacedPiece] = []
var _index: Dictionary = {}            # Vector2i cell -> { "type": int, "owner": int, "piece": PlacedPiece }
var _road_connectors: Dictionary = {}  # road edge-centers on the board
var _bridge_ends: Dictionary = {}      # placed bridges' end cells


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


## All occupied cells whose terrain is [param kind] ([enum CellType.Kind]).
func cells_of_type(kind: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _index:
		if _index[cell]["type"] == kind:
			result.append(cell)
	return result


## The placed piece covering [param cell], or null if the cell is empty.
func piece_at(cell: Vector2i) -> PlacedPiece:
	return _index[cell]["piece"] if _index.has(cell) else null


## The board's ROAD connector cells (road edge-centers). Used by the bridge finder.
func connector_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _road_connectors:
		result.append(cell)
	return result


## Whether [param block] can be placed at [param anchor]/[param rotation]: no overlap, and (unless
## the board is empty) its connectors link up per the model — road connectors attach to roads or
## bridge ends; the bridge's (water) connectors attach to roads only.
func can_place(block: BlockDefinition, anchor: Vector2i, rotation: int) -> bool:
	for cell in block.get_cells(anchor, rotation):
		if is_occupied(cell):
			return false
	if is_empty():
		return true
	var type_of := {}
	for tc in block.get_typed_cells(anchor, rotation):
		type_of[tc["cell"]] = tc["type"]
	for c in block.get_connectors(anchor, rotation):
		var road_conn := CellType.is_road(type_of.get(c, CellType.Kind.WATER))
		for neighbor in HexUtils.neighbors(c):
			if _road_connectors.has(neighbor):
				return true                 # roads link both kinds
			if road_conn and _bridge_ends.has(neighbor):
				return true                 # a road may continue across a bridge end
	return false


## Places [param block] for [param owner]. With [param checked] (default), refuses illegal moves;
## the auto-bridge passes [code]false[/code] to commit a pre-validated bridge+block. Returns success.
func place(block: BlockDefinition, anchor: Vector2i, rotation: int, owner: int = -1, checked: bool = true) -> bool:
	if checked and not can_place(block, anchor, rotation):
		return false
	var piece := PlacedPiece.new(block, anchor, rotation, owner)
	var type_at := {}
	for tc in piece.typed_cells:
		_index[tc["cell"]] = {"type": tc["type"], "owner": owner, "piece": piece}
		type_at[tc["cell"]] = tc["type"]
	# Road connectors vs bridge ends are split by the connector cell's terrain type.
	for c in piece.connector_cells:
		if CellType.is_road(type_at.get(c, CellType.Kind.WATER)):
			_road_connectors[c] = true
		else:
			_bridge_ends[c] = true
	_pieces.append(piece)
	changed.emit()
	return true


## Removes [param piece] from the board: frees its cells and drops its connectors. Returns false if
## the piece is not currently placed. Emits [signal changed] on success. Used to take back a piece
## placed during the current setup turn (re-position, rotate, or remove).
func remove_piece(piece: PlacedPiece) -> bool:
	var idx := _pieces.find(piece)
	if idx == -1:
		return false
	for tc in piece.typed_cells:
		_index.erase(tc["cell"])
	for c in piece.connector_cells:
		_road_connectors.erase(c)  # a connector cell belongs to one piece, so this is exact
		_bridge_ends.erase(c)
	_pieces.remove_at(idx)
	changed.emit()
	return true
