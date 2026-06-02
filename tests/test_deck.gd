extends GutTest
## Tests for Deck — pure draw/discard logic with an endless (reshuffle-on-empty) pile.
## A seedable RandomNumberGenerator is injected so shuffles are deterministic in tests.


func _cards(n: int) -> Array[CardDefinition]:
	var list: Array[CardDefinition] = []
	for i in n:
		var c := CardDefinition.new()
		c.id = StringName("card_%d" % i)
		list.append(c)
	return list


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_new_deck_holds_all_cards_in_draw_pile() -> void:
	var deck := Deck.new(_cards(5))
	assert_eq(deck.draw_count(), 5)
	assert_eq(deck.discard_count(), 0)


func test_draw_removes_cards_from_draw_pile() -> void:
	var deck := Deck.new(_cards(5))
	var drawn := deck.draw(2)
	assert_eq(drawn.size(), 2)
	assert_eq(deck.draw_count(), 3)


func test_drawn_cards_are_distinct() -> void:
	var drawn := Deck.new(_cards(5)).draw(3)
	assert_ne(drawn[0], drawn[1])
	assert_ne(drawn[1], drawn[2])
	assert_ne(drawn[0], drawn[2])


func test_draw_emits_drawn_signal() -> void:
	var deck := Deck.new(_cards(5))
	watch_signals(deck)
	deck.draw(2)
	assert_signal_emitted(deck, "drawn")


func test_discard_grows_discard_pile_and_signals() -> void:
	var deck := Deck.new(_cards(3))
	var drawn := deck.draw(1)
	watch_signals(deck)
	deck.discard(drawn[0])
	assert_eq(deck.discard_count(), 1)
	assert_signal_emitted(deck, "discarded")


func test_draw_reshuffles_discard_when_draw_pile_empty() -> void:
	var deck := Deck.new(_cards(2), _seeded(1))
	for c in deck.draw(2):
		deck.discard(c)
	assert_eq(deck.draw_count(), 0)
	assert_eq(deck.discard_count(), 2)
	watch_signals(deck)
	var again := deck.draw(2)
	assert_eq(again.size(), 2, "discard was reshuffled back into the draw pile")
	assert_eq(deck.discard_count(), 0)
	assert_signal_emitted(deck, "reshuffled")


func test_draw_from_fully_empty_deck_returns_empty() -> void:
	var deck := Deck.new(_cards(1))
	deck.draw(1)  # empties the draw pile, nothing discarded
	var none := deck.draw(1)
	assert_eq(none.size(), 0)
	assert_eq(deck.draw_count(), 0)


func test_return_to_top_makes_the_card_drawn_next() -> void:
	var deck := Deck.new(_cards(3))
	var first := deck.draw(1)[0]
	deck.return_to_top(first)
	assert_eq(deck.draw_count(), 3, "the card is back in the draw pile")
	assert_eq(deck.draw(1)[0], first, "the returned card is on top, drawn first")


func test_total_card_count_is_preserved_through_recycle() -> void:
	var deck := Deck.new(_cards(3), _seeded(7))
	for c in deck.draw(3):
		deck.discard(c)
	assert_eq(deck.draw(3).size(), 3, "all three cards come back after the reshuffle")


func test_reshuffle_folds_discard_back_into_draw_pile() -> void:
	var deck := Deck.new(_cards(4), _seeded(3))
	for c in deck.draw(2):
		deck.discard(c)
	assert_eq(deck.draw_count(), 2)
	assert_eq(deck.discard_count(), 2)
	watch_signals(deck)
	deck.reshuffle()
	assert_eq(deck.draw_count(), 4, "the whole deck is back in the draw pile")
	assert_eq(deck.discard_count(), 0)
	assert_signal_emitted(deck, "reshuffled")


func test_shuffle_is_deterministic_for_equal_seeds() -> void:
	var a := Deck.new(_cards(6), _seeded(42))
	var b := Deck.new(_cards(6), _seeded(42))
	a.shuffle()
	b.shuffle()
	var ids_a: Array = []
	var ids_b: Array = []
	for c in a.draw(6):
		ids_a.append(c.id)
	for c in b.draw(6):
		ids_b.append(c.id)
	assert_eq(ids_a, ids_b, "same cards + same seed shuffle identically")
