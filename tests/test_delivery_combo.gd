extends GutTest
## Tests for DeliveryCombo — an enseigne×destinataire pairing and its status cycle.


func _enseigne() -> EnseigneDefinition:
	var e := EnseigneDefinition.new()
	e.id = &"ikeo"
	return e


func _destinataire() -> DestinataireDefinition:
	var d := DestinataireDefinition.new()
	d.id = &"keiona"
	return d


func test_new_combo_is_available() -> void:
	var c := DeliveryCombo.new(_enseigne(), _destinataire())
	assert_eq(c.status, DeliveryStatus.Kind.DISPONIBLE)
	assert_true(c.is_available())
	assert_false(c.is_done())


func test_advance_cycles_through_statuses() -> void:
	var c := DeliveryCombo.new(_enseigne(), _destinataire())
	assert_true(c.advance())
	assert_eq(c.status, DeliveryStatus.Kind.RESERVE)
	assert_true(c.advance())
	assert_eq(c.status, DeliveryStatus.Kind.EN_COURS)
	assert_true(c.advance())
	assert_eq(c.status, DeliveryStatus.Kind.LIVREE)
	assert_true(c.is_done())


func test_advance_past_delivered_is_a_noop() -> void:
	var c := DeliveryCombo.new(_enseigne(), _destinataire())
	c.advance(); c.advance(); c.advance()  # -> LIVREE
	assert_false(c.advance(), "cannot advance past LIVREE")


func test_status_label_is_french() -> void:
	assert_eq(DeliveryStatus.label(DeliveryStatus.Kind.EN_COURS), "En cours")
