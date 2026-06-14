extends GutTest
## Tests for Delivery — a drive→recipient link spanning one or two tiles, and its tile owners.


func _piece(owner: int) -> PlacedPiece:
	var b := BlockDefinition.new()
	b.id = &"t"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.URBAN]
	b.connectors = [] as Array[Vector2i]
	return PlacedPiece.new(b, Vector2i.ZERO, 0, owner)


func test_single_tile_delivery() -> void:
	var p := _piece(PlayerColor.Kind.RED)
	var d := Delivery.new(Vector2i(0, 0), Vector2i(1, 0), [p] as Array[PlacedPiece])
	assert_true(d.is_single_tile())
	assert_eq(d.tile_owners(), [PlayerColor.Kind.RED])


func test_two_tile_delivery() -> void:
	var tiles := [_piece(PlayerColor.Kind.RED), _piece(PlayerColor.Kind.BLUE)] as Array[PlacedPiece]
	var d := Delivery.new(Vector2i(0, 0), Vector2i(5, 0), tiles)
	assert_false(d.is_single_tile())
	assert_eq(d.tile_owners().size(), 2)


func test_starts_unpicked_and_undelivered() -> void:
	var d := Delivery.new(Vector2i(0, 0), Vector2i(1, 0), [_piece(0)] as Array[PlacedPiece])
	assert_false(d.picked_up)
	assert_false(d.delivered)
	assert_eq(d.carrier_index, -1)


func test_recycle_clips_a_new_recipient_and_resets_state() -> void:
	var d := Delivery.new(Vector2i(0, 0), Vector2i(1, 0), [_piece(0)] as Array[PlacedPiece])
	d.picked_up = true
	d.delivered = true
	d.carrier_index = 2
	var fresh := DestinataireDefinition.new()
	fresh.id = &"fresh"
	d.recycle(fresh)
	assert_eq(d.destinataire, fresh)
	assert_false(d.picked_up)
	assert_false(d.delivered)
	assert_eq(d.carrier_index, -1)
