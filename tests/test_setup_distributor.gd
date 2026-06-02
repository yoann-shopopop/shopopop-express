extends GutTest
## Tests for SetupDistributor — draws 3 shared patterns and builds each player's pieces + start.

var _library: Array[BlockDefinition]
var _bridge: BlockDefinition


func before_each() -> void:
	_library = []
	for i in 6:
		_library.append(_pattern(StringName("p%d" % i)))
	_bridge = _pattern(&"bridge")


# A pattern with a ROUTE cell and a GREEN cell on the edge of that road (a candidate start).
func _pattern(id: StringName) -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = id
	b.cells = [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.ROUTE, CellType.Kind.GREEN]
	b.connectors = [Vector2i(0, 0)] as Array[Vector2i]
	return b


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return rng


func test_builds_one_player_per_requested_count() -> void:
	var players := SetupDistributor.build_players(3, _library, _bridge, _seeded_rng())
	assert_eq(players.size(), 3)


func test_each_player_gets_three_patterns_plus_a_bridge() -> void:
	var players := SetupDistributor.build_players(2, _library, _bridge, _seeded_rng())
	for player in players:
		assert_eq(player.pieces.size(), 4, "3 patterns + 1 bridge")


func test_all_players_share_the_same_three_patterns() -> void:
	var players := SetupDistributor.build_players(4, _library, _bridge, _seeded_rng())
	var first_ids := _pattern_ids(players[0])
	for player in players:
		assert_eq(_pattern_ids(player), first_ids, "patterns are identical for everyone")


func test_drawn_patterns_are_distinct() -> void:
	var players := SetupDistributor.build_players(2, _library, _bridge, _seeded_rng())
	var ids := _pattern_ids(players[0])
	var unique := {}
	for id in ids:
		unique[id] = true
	assert_eq(unique.size(), 3, "three distinct patterns")


func test_players_have_distinct_colors() -> void:
	var players := SetupDistributor.build_players(4, _library, _bridge, _seeded_rng())
	var colors := {}
	for player in players:
		colors[player.color] = true
	assert_eq(colors.size(), 4)


func test_start_is_a_green_cell_of_one_of_the_players_blocks() -> void:
	var players := SetupDistributor.build_players(3, _library, _bridge, _seeded_rng())
	for player in players:
		assert_not_null(player.start_block, "a start block is assigned")
		var pattern_blocks := player.pieces.slice(0, 3)
		assert_true(player.start_block in pattern_blocks, "start is on a pattern block, not the bridge")
		var idx := player.start_block.cells.find(player.start_cell)
		assert_gte(idx, 0, "start cell belongs to the block")
		assert_eq(player.start_block.cell_types[idx], CellType.Kind.GREEN, "start sits on a green cell")
		# And that green cell is on the edge of a road.
		var roads := {}
		for j in player.start_block.cells.size():
			if CellType.is_road(player.start_block.cell_types[j]):
				roads[player.start_block.cells[j]] = true
		var roadside := false
		for nb in HexUtils.neighbors(player.start_cell):
			if roads.has(nb):
				roadside = true
		assert_true(roadside, "start is on the edge of a road")


# The pattern ids (first 3 pieces) of a player.
func _pattern_ids(player: Player) -> Array:
	var ids := []
	for i in 3:
		ids.append(player.pieces[i].id)
	return ids
