extends GutTest
## Tests for DeliveryGenerator — random pairing, status advance/complete, recipient recycling.


func _enseignes(n: int) -> Array[EnseigneDefinition]:
	var result: Array[EnseigneDefinition] = []
	for i in n:
		var e := EnseigneDefinition.new()
		e.id = StringName("e%d" % i)
		result.append(e)
	return result


func _destinataires(n: int) -> Array[DestinataireDefinition]:
	var result: Array[DestinataireDefinition] = []
	for i in n:
		var d := DestinataireDefinition.new()
		d.id = StringName("d%d" % i)
		result.append(d)
	return result


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	return rng


func test_builds_one_combo_per_slot() -> void:
	var gen := DeliveryGenerator.new(_enseignes(4), _destinataires(10), 4, _seeded_rng())
	assert_eq(gen.combos().size(), 4)


func test_recipients_are_distinct_across_combos() -> void:
	var gen := DeliveryGenerator.new(_enseignes(4), _destinataires(10), 4, _seeded_rng())
	var ids := {}
	for combo in gen.combos():
		ids[combo.destinataire.id] = true
	assert_eq(ids.size(), 4, "no recipient reused simultaneously")


func test_advance_stops_at_en_cours() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(4), 1, _seeded_rng())
	assert_true(gen.advance(0))   # RESERVE
	assert_true(gen.advance(0))   # EN_COURS
	assert_false(gen.advance(0), "advance does not reach LIVREE")
	assert_eq(gen.combos()[0].status, DeliveryStatus.Kind.EN_COURS)


func test_complete_recycles_a_new_recipient() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(4), 1, _seeded_rng())
	var old_id := gen.combos()[0].destinataire.id
	gen.advance(0); gen.advance(0)  # -> EN_COURS
	assert_true(gen.complete(0))
	var combo := gen.combos()[0]
	assert_eq(combo.status, DeliveryStatus.Kind.DISPONIBLE, "recycled back to available")
	assert_ne(combo.destinataire, null, "a new recipient was clipped")
	assert_ne(combo.destinataire.id, old_id, "different recipient drawn from the pool")


func test_complete_requires_en_cours() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(4), 1, _seeded_rng())
	assert_false(gen.complete(0), "cannot complete a DISPONIBLE combo")


func test_pool_exhaustion_leaves_an_empty_combo() -> void:
	# 2 recipients, 1 slot: 1 drawn at init, 1 left. Complete once -> last drawn. Complete again -> none.
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(2), 1, _seeded_rng())
	gen.advance(0); gen.advance(0); gen.complete(0)  # uses the 2nd recipient
	assert_eq(gen.remaining_recipients(), 0)
	gen.advance(0); gen.advance(0)
	assert_true(gen.complete(0))
	assert_null(gen.combos()[0].destinataire, "no recipient left to clip")


func test_recycle_draws_a_new_recipient_regardless_of_status() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(4), 1, _seeded_rng())
	var old_id := gen.combos()[0].destinataire.id
	var next := gen.recycle(0)  # no advance/EN_COURS required
	assert_ne(next, null)
	assert_ne(gen.combos()[0].destinataire.id, old_id, "a different recipient is clipped")


func test_more_slots_than_enseignes_reuses_brands() -> void:
	# 2 enseignes, 3 slots, 6 recipients -> 3 combos; the 3rd reuses the 1st brand (cycled).
	var gen := DeliveryGenerator.new(_enseignes(2), _destinataires(6), 3, _seeded_rng())
	assert_eq(gen.combos().size(), 3)
	assert_eq(gen.combos()[2].enseigne.id, gen.combos()[0].enseigne.id)


func test_max_deliveries_caps_the_total_at_the_tile_count() -> void:
	# Rules: total deliveries = number of placed tiles. 10 identities, 4 slots, cap 4:
	# everything is clipped at init, nothing is left to recycle.
	var gen := DeliveryGenerator.new(_enseignes(4), _destinataires(10), 4, _seeded_rng(), 4)
	assert_eq(gen.combos().size(), 4)
	assert_eq(gen.remaining_recipients(), 0, "the pool holds no extra identity beyond the cap")
	gen.advance(0); gen.advance(0)
	assert_true(gen.complete(0))
	assert_null(gen.combos()[0].destinataire, "no recycling: the drive is left free after delivery")


func test_negative_max_deliveries_leaves_the_pool_uncapped() -> void:
	var gen := DeliveryGenerator.new(_enseignes(4), _destinataires(10), 4, _seeded_rng(), -1)
	assert_eq(gen.remaining_recipients(), 6, "10 identities minus the 4 clipped at init")


func test_peek_upcoming_does_not_consume_the_pool() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(6), 1, _seeded_rng())
	var before := gen.remaining_recipients()
	var peeked := gen.peek_upcoming(2)
	assert_eq(peeked.size(), 2)
	assert_eq(gen.remaining_recipients(), before, "peeking must not draw")


func test_peek_upcoming_matches_the_actual_draw_order() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(4), 1, _seeded_rng())
	var peeked := gen.peek_upcoming(3)
	for expected in peeked:
		var drawn := gen.recycle(0)
		assert_eq(drawn, expected, "recycle() draws exactly what was peeked, in the same order")


func test_peek_upcoming_returns_fewer_when_the_pool_is_almost_empty() -> void:
	var gen := DeliveryGenerator.new(_enseignes(1), _destinataires(2), 1, _seeded_rng())  # 1 clipped, 1 left
	assert_eq(gen.peek_upcoming(5).size(), 1)
