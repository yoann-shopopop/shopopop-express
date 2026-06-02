extends GutTest
## Integration smoke test for GameRoot: setting it up wires dice/pawns/UI/controller without error
## and spawns one pawn view per player. Runs in GUT's SceneTree (nodes allowed).


func _tile() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"start_tile"
	b.cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.GREEN, CellType.Kind.ROUTE, CellType.Kind.ROUTE]
	b.connectors = [Vector2i(1, 0)] as Array[Vector2i]
	return b


func _player(index: int, color: int, start_block: BlockDefinition) -> Player:
	var p := Player.new(color)
	p.index = index
	p.start_block = start_block
	p.start_cell = Vector2i(0, 0)
	return p


func test_setup_spawns_one_pawn_view_per_player_without_error() -> void:
	var board := Board.new()
	var tile := _tile()
	board.place(tile, Vector2i.ZERO, 0, 0)
	var players: Array[Player] = [
		_player(0, PlayerColor.Kind.BLUE, tile),
		_player(1, PlayerColor.Kind.RED, tile),
	]
	var camera := Camera3D.new()
	add_child_autofree(camera)

	var root := GameRoot.new()
	add_child_autofree(root)
	root.setup(board, players, camera)

	var pawn_views := 0
	for child in root.get_children():
		if child is PawnView:
			pawn_views += 1
	assert_eq(pawn_views, 2, "one pawn view per player")
