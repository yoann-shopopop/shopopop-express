class_name TutorialScenario
extends RefCounted
## Builds the hand-authored, deterministic mini-board for the first-time tutorial: a single tile
## (GREEN start → ROUTE → EVENT → ROUTE → URBAN drive → GREEN recipient, in a straight line) whose
## one delivery is mono-tile — scoring the full 5+10+10=25 the moment it's completed, the clearest
## possible demonstration of the territorial scoring rule. Pure logic (no Node); [GameRoot]'s
## deterministic-session overrides (forced_deliveries/forced_event_order — see [method GameRoot.setup])
## make this reproducible without needing to force dice values too: the walk is short enough (5 cells
## end to end) that any 2d6 roll makes real progress, across one turn or two.

const _ENSEIGNE_PATH := "res://resources/enseignes/fanfan_fleurs.tres"
const _DESTINATAIRE_PATH := "res://resources/destinataires/mamie_turbo.tres"
const _EVENT_AVANTAGE_PATH := "res://resources/events/grand_soleil.tres"
const _EVENT_MALUS_PATH := "res://resources/events/recharge_batterie.tres"

## Cell coordinates, exposed so [TutorialDirector] can recognize "arrived at the drive/recipient"
## without re-deriving them from the board.
const START_CELL := Vector2i(0, 0)
const EVENT_CELL := Vector2i(2, 0)
const DRIVE_CELL := Vector2i(4, 0)
const RECIPIENT_CELL := Vector2i(4, 1)


## The single tile, already placed at the origin on a fresh [param board]. Owned by [param color]
## (the tutorial player's own district — makes the mono-tile delivery score the full 25).
static func build_board(color: int) -> Board:
	var board := Board.new()
	var tile := BlockDefinition.new()
	tile.id = &"tutorial_tile"
	tile.cells = [
		START_CELL, Vector2i(1, 0), EVENT_CELL, Vector2i(3, 0), DRIVE_CELL, RECIPIENT_CELL,
	] as Array[Vector2i]
	tile.cell_types = [
		CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.EVENT,
		CellType.Kind.ROUTE, CellType.Kind.URBAN, CellType.Kind.GREEN,
	]
	tile.connectors = []  # standalone board: never assembled against another piece
	board.place(tile, Vector2i.ZERO, 0, color)
	return board


## A single Humain player, seated on the tile's start cell.
static func build_player(color: int, board: Board) -> Player:
	var player := Player.new(color)
	player.index = 0
	player.start_block = board.pieces()[0].block_def
	player.start_cell = START_CELL
	return player


## The one mono-tile delivery (drive + recipient both on the tutorial's only tile).
static func build_delivery(board: Board) -> Delivery:
	var piece: PlacedPiece = board.pieces()[0]
	var delivery := Delivery.new(DRIVE_CELL, RECIPIENT_CELL, [piece] as Array[PlacedPiece])
	if ResourceLoader.exists(_ENSEIGNE_PATH):
		delivery.enseigne = load(_ENSEIGNE_PATH)
	if ResourceLoader.exists(_DESTINATAIRE_PATH):
		delivery.destinataire = load(_DESTINATAIRE_PATH)
	if delivery.destinataire == null:
		delivery.destinataire = DestinataireDefinition.new()  # is_reservable() requires a non-null one
	return delivery


## The forced draw order for the tutorial's one event cell: an Avantage (Grand Soleil, +3 cases) and
## a Malus (Recharge de Batterie, -3), so the real "pioche 2, garde 1" choice means something.
static func build_event_order() -> Array[CardDefinition]:
	var order: Array[CardDefinition] = []
	if ResourceLoader.exists(_EVENT_AVANTAGE_PATH):
		order.append(load(_EVENT_AVANTAGE_PATH))
	if ResourceLoader.exists(_EVENT_MALUS_PATH):
		order.append(load(_EVENT_MALUS_PATH))
	return order
