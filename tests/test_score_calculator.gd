extends GutTest
## Tests for ScoreCalculator — 5 base + 10 per owned tile, with the single-owned-tile = 20 exception.


const RED := PlayerColor.Kind.RED
const BLUE := PlayerColor.Kind.BLUE


func _char_owning(colors: Array[int]) -> CharacterDefinition:
	var c := CharacterDefinition.new()
	c.colors = colors
	return c


func _piece(owner: int) -> PlacedPiece:
	var b := BlockDefinition.new()
	b.id = &"t"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.URBAN]
	b.connectors = [] as Array[Vector2i]
	return PlacedPiece.new(b, Vector2i.ZERO, 0, owner)


func _delivery(owners: Array[int]) -> Delivery:
	var tiles: Array[PlacedPiece] = []
	for o in owners:
		tiles.append(_piece(o))
	return Delivery.new(Vector2i(0, 0), Vector2i(1, 0), tiles)


func test_single_tile_that_is_mine_scores_twenty() -> void:
	var d := _delivery([RED])
	assert_eq(ScoreCalculator.score_delivery(d, _char_owning([RED])), 20)


func test_two_tiles_both_mine_score_twentyfive() -> void:
	var d := _delivery([RED, RED])
	assert_eq(ScoreCalculator.score_delivery(d, _char_owning([RED])), 25)


func test_two_tiles_one_mine_scores_fifteen() -> void:
	var d := _delivery([RED, BLUE])
	assert_eq(ScoreCalculator.score_delivery(d, _char_owning([RED])), 15)


func test_no_tile_mine_scores_only_the_base() -> void:
	var d := _delivery([BLUE])
	assert_eq(ScoreCalculator.score_delivery(d, _char_owning([RED])), 5)
