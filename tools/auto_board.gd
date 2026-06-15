class_name AutoBoard
extends RefCounted
## Dev/test helper: assembles a full board by auto-placing every player's blocks legally
## (route-to-route), mirroring what a human does in the setup phase. Reuses the real
## [SetupDistributor] / [SetupPhase] / [Board] so the soak test and the screenshot harness exercise
## the same code path as a real game. Pure logic — no nodes.

const PATTERNS_DIR := "res://resources/blocks/patterns/"
const CHARACTERS_DIR := "res://resources/characters/"
const BRIDGE_PATH := "res://resources/blocks/bridge.tres"


## Builds [param count] players and places all their blocks. Returns
## [code]{ "board": Board, "players": Array[Player], "ok": bool }[/code]; [code]ok[/code] is false if
## a block could not be placed legally (should never happen with the shipped patterns).
static func build(count: int, rng: RandomNumberGenerator) -> Dictionary:
	var library := _load_dir(PATTERNS_DIR) as Array
	var characters := _load_dir(CHARACTERS_DIR) as Array
	var bridge: BlockDefinition = load(BRIDGE_PATH)
	var typed_library: Array[BlockDefinition] = []
	for b in library:
		typed_library.append(b)
	var typed_chars: Array[CharacterDefinition] = []
	for c in characters:
		typed_chars.append(c)
	var players := SetupDistributor.build_players(count, typed_library, bridge, rng, typed_chars)
	var board := Board.new()
	var phase := SetupPhase.new(players, board)
	var ok := true
	var guard := 0
	while not phase.is_finished() and guard < count * 6 + 6:
		guard += 1
		if not _place_one(phase, board):
			ok = false
			break
		phase.finish_turn()
	return {"board": board, "players": players, "ok": ok and phase.is_finished()}


# Places the current player's first remaining block at the first legal spot found.
static func _place_one(phase: SetupPhase, board: Board) -> bool:
	var player := phase.current_player()
	if player.pieces.is_empty():
		return false
	var block: BlockDefinition = player.pieces[0]
	if board.is_empty():
		return phase.try_place(0, Vector2i.ZERO, 0)
	var spot := _first_legal(board, block)
	if spot.is_empty():
		return false
	return phase.try_place(0, spot["anchor"], spot["rotation"])


# Finds the first legal (anchor, rotation) by trying to land one of the block's connectors next to an
# existing road connector — exactly the adjacency [Board.can_place] requires. Targeted, so it is cheap.
static func _first_legal(board: Board, block: BlockDefinition) -> Dictionary:
	for existing in board.connector_cells():
		for dir in HexUtils.DIRECTIONS:
			var target: Vector2i = existing + dir
			for rot in range(6):
				for local in block.connectors:
					var anchor: Vector2i = target - HexUtils.rotate(local, rot)
					if board.can_place(block, anchor, rot):
						return {"anchor": anchor, "rotation": rot}
	return {}


static func _load_dir(path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(path + file))
	return result
