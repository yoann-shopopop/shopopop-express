extends GutTest
## Smoke test for ClipCardView: binding a combo builds the enseigne and destinataire parts; the status
## insert appears only when the combo is not DISPONIBLE.


func _combo(status: int) -> DeliveryCombo:
	var e := EnseigneDefinition.new()
	e.display_name = "IKEO"
	var d := DestinataireDefinition.new()
	d.display_name = "Keiona"
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
