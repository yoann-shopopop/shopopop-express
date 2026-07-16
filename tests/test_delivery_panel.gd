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
