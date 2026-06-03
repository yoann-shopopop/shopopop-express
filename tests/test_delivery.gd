extends GutTest
## Tests for Delivery — a drive→recipient link, its tile owners, and its status lifecycle.


func _piece(owner: int) -> PlacedPiece:
	var b := BlockDefinition.new()
	b.id = &"t"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.URBAN]
	b.connectors = [] as Array[Vector2i]
	return PlacedPiece.new(b, Vector2i.ZERO, 0, owner)


func _delivery(owner: int) -> Delivery:
	return Delivery.new(Vector2i(0, 0), Vector2i(1, 0), [_piece(owner)] as Array[PlacedPiece])


func test_single_tile_delivery() -> void:
	var d := _delivery(PlayerColor.Kind.RED)
	assert_true(d.is_single_tile())
	assert_eq(d.drive_tile_owner(), PlayerColor.Kind.RED)
	assert_eq(d.recipient_tile_owner(), PlayerColor.Kind.RED)


func test_two_tile_delivery_owners_are_drive_then_recipient() -> void:
	var tiles := [_piece(PlayerColor.Kind.RED), _piece(PlayerColor.Kind.BLUE)] as Array[PlacedPiece]
	var d := Delivery.new(Vector2i(0, 0), Vector2i(5, 0), tiles)
	assert_eq(d.drive_tile_owner(), PlayerColor.Kind.RED)
	assert_eq(d.recipient_tile_owner(), PlayerColor.Kind.BLUE)


func test_starts_disponible_and_unreserved() -> void:
	var d := _delivery(0)
	assert_eq(d.status, DeliveryStatus.Kind.DISPONIBLE)
	assert_eq(d.reserved_by, -1)


func test_is_reservable_requires_disponible_with_a_recipient() -> void:
	var d := _delivery(0)
	assert_false(d.is_reservable(), "no recipient yet")
	d.destinataire = DestinataireDefinition.new()
	assert_true(d.is_reservable(), "disponible + recipient")
	d.status = DeliveryStatus.Kind.RESERVE
	assert_false(d.is_reservable(), "already reserved")


func test_recycle_clips_a_new_recipient_and_resets_state() -> void:
	var d := _delivery(0)
	d.status = DeliveryStatus.Kind.EN_COURS
	d.reserved_by = 2
	var fresh := DestinataireDefinition.new()
	fresh.id = &"fresh"
	d.recycle(fresh)
	assert_eq(d.destinataire, fresh)
	assert_eq(d.status, DeliveryStatus.Kind.DISPONIBLE)
	assert_eq(d.reserved_by, -1)
