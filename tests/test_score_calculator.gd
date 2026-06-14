extends GutTest
## Tests for ScoreCalculator — BASE(5) + 10 si la tuile du drive est ma couleur + 10 si la tuile du
## destinataire est ma couleur. Mono-tuile ⇒ 5 ou 25.


const RED := PlayerColor.Kind.RED
const BLUE := PlayerColor.Kind.BLUE


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


func test_single_tile_that_is_mine_scores_twentyfive() -> void:
	var d := _delivery([RED])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 25)


func test_single_tile_not_mine_scores_only_the_base() -> void:
	var d := _delivery([BLUE])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 5)


func test_two_tiles_only_drive_is_mine_scores_fifteen() -> void:
	var d := _delivery([RED, BLUE])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 15)


func test_two_tiles_only_recipient_is_mine_scores_fifteen() -> void:
	var d := _delivery([BLUE, RED])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 15)


func test_two_tiles_both_mine_score_twentyfive() -> void:
	var d := _delivery([RED, RED])
	assert_eq(ScoreCalculator.score_delivery(d, RED), 25)
