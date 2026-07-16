extends GutTest
## Tests for DeliveryCombo — an enseigne×destinataire pairing and its status cycle.


func _enseigne() -> EnseigneDefinition:
	var e := EnseigneDefinition.new()
	e.id = &"visse_et_vrille"
	return e


func _destinataire() -> DestinataireDefinition:
	var d := DestinataireDefinition.new()
	d.id = &"mamie_turbo"
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


# Colorblind accessibility: each status has an icon doubling its color, and the four distinct icons.
func test_status_icons_are_distinct() -> void:
	var icons := {}
	for kind in [DeliveryStatus.Kind.DISPONIBLE, DeliveryStatus.Kind.RESERVE, DeliveryStatus.Kind.EN_COURS, DeliveryStatus.Kind.LIVREE]:
		icons[DeliveryStatus.icon(kind)] = true
	assert_eq(icons.size(), 4, "four distinct status icons")


func test_reset_clips_a_new_recipient_and_becomes_available() -> void:
	var c := DeliveryCombo.new(_enseigne(), _destinataire())
	c.advance(); c.advance()  # move off DISPONIBLE
	var fresh := DestinataireDefinition.new()
	fresh.id = &"fresh"
	c.reset(fresh)
	assert_eq(c.status, DeliveryStatus.Kind.DISPONIBLE)
	assert_eq(c.destinataire, fresh)
