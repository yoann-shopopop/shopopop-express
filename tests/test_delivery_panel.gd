extends GutTest
## Tests for DeliveryPanel — card hover wiring (the delivery_hovered/delivery_unhovered signals that
## GameRoot uses to highlight the drive/recipient cells on the board).


func _players() -> Array[Player]:
	var p := Player.new(PlayerColor.Kind.BLUE)
	p.index = 0
	return [p]


func _delivery() -> Delivery:
	var d := Delivery.new(Vector2i(0, 0), Vector2i(1, 0), [] as Array[PlacedPiece])
	d.destinataire = DestinataireDefinition.new()
	d.enseigne = EnseigneDefinition.new()
	return d


func test_hovering_a_card_emits_delivery_hovered_with_that_delivery() -> void:
	var panel := DeliveryPanel.new()
	add_child_autofree(panel)
	var delivery := _delivery()
	panel.build([delivery] as Array[Delivery], _players())
	watch_signals(panel)
	var card: Control = panel._list.get_child(0)
	card.mouse_entered.emit()
	assert_signal_emitted_with_parameters(panel, "delivery_hovered", [delivery])


func test_unhovering_a_card_emits_delivery_unhovered() -> void:
	var panel := DeliveryPanel.new()
	add_child_autofree(panel)
	var delivery := _delivery()
	panel.build([delivery] as Array[Delivery], _players())
	watch_signals(panel)
	var card: Control = panel._list.get_child(0)
	card.mouse_exited.emit()
	assert_signal_emitted_with_parameters(panel, "delivery_unhovered", [delivery])


func _all_descendants(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


# Without illustrator art, a card used to show a plain dark void for both the enseigne logo and the
# destinataire medallion — every delivery looked identically "unfinished". Now it falls back to
# initials (IdentityFallback), same as the 3D board tokens.
func test_card_shows_initials_fallback_for_untextured_enseigne_and_destinataire() -> void:
	var panel := DeliveryPanel.new()
	add_child_autofree(panel)
	var d := Delivery.new(Vector2i(0, 0), Vector2i(1, 0), [] as Array[PlacedPiece])
	var enseigne := EnseigneDefinition.new()
	enseigne.display_name = "Le Fournil d'Hector"
	d.enseigne = enseigne
	var destinataire := DestinataireDefinition.new()
	destinataire.display_name = "Mamie Turbo"
	d.destinataire = destinataire
	panel.build([d] as Array[Delivery], _players())
	var card: Control = panel._list.get_child(0)
	var labels: Array[String] = []
	for descendant in _all_descendants(card):
		if descendant is Label:
			labels.append(descendant.text)
	assert_true(labels.has("FD"), "enseigne initials fallback shown")
	assert_true(labels.has("MT"), "destinataire initials fallback shown")
