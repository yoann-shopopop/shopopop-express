extends GutTest
## Smoke test for ClipCardView: binding a combo builds the enseigne and destinataire parts; the status
## insert appears only when the combo is not DISPONIBLE.


func _combo(status: int) -> DeliveryCombo:
	var e := EnseigneDefinition.new()
	e.display_name = "Visse & Vrille"
	var d := DestinataireDefinition.new()
	d.display_name = "Mamie Turbo"
	var c := DeliveryCombo.new(e, d)
	c.status = status
	return c


func test_bind_available_has_no_status_insert() -> void:
	var view := ClipCardView.new()
	add_child_autofree(view)
	view.bind(_combo(DeliveryStatus.Kind.DISPONIBLE))
	assert_false(view.has_status_insert(), "no insert while available")


func test_bind_reserved_shows_status_insert() -> void:
	var view := ClipCardView.new()
	add_child_autofree(view)
	view.bind(_combo(DeliveryStatus.Kind.RESERVE))
	assert_true(view.has_status_insert(), "insert shown when reserved")


func _min_block() -> BlockDefinition:
	var b := BlockDefinition.new()
	b.id = &"t"
	b.cells = [Vector2i(0, 0)] as Array[Vector2i]
	b.cell_types = [CellType.Kind.URBAN]
	b.connectors = [] as Array[Vector2i]
	return b


func test_bind_delivery_shows_status_insert_when_not_available() -> void:
	var piece := PlacedPiece.new(_min_block(), Vector2i.ZERO, 0, 0)
	var d := Delivery.new(Vector2i(0, 0), Vector2i(1, 0), [piece] as Array[PlacedPiece])
	d.enseigne = EnseigneDefinition.new()
	d.destinataire = DestinataireDefinition.new()
	var view := ClipCardView.new()
	add_child_autofree(view)
	view.bind_delivery(d)
	assert_false(view.has_status_insert(), "DISPONIBLE → pas d'insert")
	d.status = DeliveryStatus.Kind.EN_COURS
	view.bind_delivery(d)
	assert_true(view.has_status_insert(), "EN_COURS → insert visible")
