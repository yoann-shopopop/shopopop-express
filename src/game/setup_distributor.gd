class_name SetupDistributor
extends RefCounted
## Builds the players' starting pieces for a game: draws distinct patterns from the library
## (shared by everyone, for balance — 3 each up to 3 players, 2 each from 4 players, per the rules'
## setup table), clones them in each player's color, adds a bridge, and assigns each player a start
## point (random green cell of a random one of their blocks). Pure & seedable.


## Tiles dealt to each player: 3 up to 3 players, 2 from 4 players (rules, « Mise en place »).
static func tiles_per_player(count: int) -> int:
	return 3 if count <= 3 else 2


## Returns [param count] players, each with the same drawn patterns (recolored) + a bridge.
## Characters: if [param chosen] holds one per seat it is used as-is (the character-select screen);
## otherwise, when [param characters] is non-empty, each player is dealt a distinct random one.
static func build_players(
	count: int,
	library: Array[BlockDefinition],
	bridge: BlockDefinition,
	rng: RandomNumberGenerator,
	characters: Array[CharacterDefinition] = [],
	chosen: Array[CharacterDefinition] = [],
) -> Array[Player]:
	var drawn := _draw_distinct(library, tiles_per_player(count), rng)
	var colors := PlayerColor.all()
	var dealt := _draw_distinct_characters(characters, count, rng)
	var players: Array[Player] = []
	for i in count:
		var player := Player.new(colors[i % colors.size()])
		player.index = i
		if i < chosen.size() and chosen[i] != null:
			player.character = chosen[i]
		elif i < dealt.size():
			player.character = dealt[i]
		var tint := PlayerColor.to_color(player.color)
		for pattern in drawn:
			player.pieces.append(_clone(pattern, tint))
		player.bridge = _clone(bridge, tint)  # held aside; free, auto-used with a block
		_assign_start(player, rng)
		players.append(player)
	return players


# Picks [param n] distinct characters using a seeded Fisher-Yates draw (empty if none provided).
static func _draw_distinct_characters(characters: Array[CharacterDefinition], n: int, rng: RandomNumberGenerator) -> Array[CharacterDefinition]:
	var pool := characters.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: CharacterDefinition = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, min(n, pool.size()))


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


# Assigns the start to a random green cell of a random pattern block (never the bridge, which is
# held aside in player.bridge).
static func _assign_start(player: Player, rng: RandomNumberGenerator) -> void:
	var block_index := rng.randi_range(0, player.pieces.size() - 1)
	var block: BlockDefinition = player.pieces[block_index]
	player.start_block = block

	var roads := {}
	for i in block.cells.size():
		if CellType.is_road(block.cell_types[i]):
			roads[block.cells[i]] = true

	# Prefer green cells on the edge of a road; fall back to any green.
	var roadside: Array[Vector2i] = []
	var any_green: Array[Vector2i] = []
	for i in block.cells.size():
		if block.cell_types[i] != CellType.Kind.GREEN:
			continue
		any_green.append(block.cells[i])
		for nb in HexUtils.neighbors(block.cells[i]):
			if roads.has(nb):
				roadside.append(block.cells[i])
				break

	var pool := roadside if not roadside.is_empty() else any_green
	if not pool.is_empty():
		player.start_cell = pool[rng.randi_range(0, pool.size() - 1)]
