class_name SetupDistributor
extends RefCounted
## Builds the players' starting pieces for a game: draws 3 distinct patterns from the library
## (shared by everyone, for balance), clones them in each player's color, adds a bridge, and assigns
## each player a start point (random green cell of a random one of their blocks). Pure & seedable.


## Returns [param count] players (2..4), each with the same 3 drawn patterns (recolored) + a bridge.
static func build_players(
	count: int,
	library: Array[BlockDefinition],
	bridge: BlockDefinition,
	rng: RandomNumberGenerator,
) -> Array[Player]:
	var drawn := _draw_distinct(library, 3, rng)
	var colors := PlayerColor.all()
	var players: Array[Player] = []
	for i in count:
		var player := Player.new(colors[i])
		var tint := PlayerColor.to_color(player.color)
		for pattern in drawn:
			player.pieces.append(_clone(pattern, tint))
		player.pieces.append(_clone(bridge, tint))
		_assign_start(player, rng)
		players.append(player)
	return players


# Picks [param n] distinct entries from [param library] using a seeded Fisher-Yates draw.
static func _draw_distinct(library: Array[BlockDefinition], n: int, rng: RandomNumberGenerator) -> Array[BlockDefinition]:
	var indices := range(library.size())
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	var result: Array[BlockDefinition] = []
	for k in n:
		result.append(library[indices[k]])
	return result


static func _clone(block: BlockDefinition, tint: Color) -> BlockDefinition:
	var copy: BlockDefinition = block.duplicate(true)
	copy.color = tint
	return copy


# Assigns the start to a random green cell of a random pattern block (indices 0..2, not the bridge).
static func _assign_start(player: Player, rng: RandomNumberGenerator) -> void:
	var block_index := rng.randi_range(0, 2)
	var block: BlockDefinition = player.pieces[block_index]
	var green_cells: Array[Vector2i] = []
	for i in block.cells.size():
		if block.cell_types[i] == CellType.Kind.GREEN:
			green_cells.append(block.cells[i])
	player.start_block = block
	if not green_cells.is_empty():
		player.start_cell = green_cells[rng.randi_range(0, green_cells.size() - 1)]
