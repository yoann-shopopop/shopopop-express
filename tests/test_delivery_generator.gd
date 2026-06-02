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
