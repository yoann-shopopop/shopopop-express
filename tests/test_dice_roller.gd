extends GutTest
## Tests for DiceRoller — rolls X D6 and records the result. A seeded RNG makes rolls deterministic.


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_roll_returns_requested_count() -> void:
	assert_eq(DiceRoller.new().roll(3).size(), 3)


func test_roll_values_are_within_one_to_six() -> void:
	for v in DiceRoller.new(_seeded(123)).roll(60):
		assert_between(v, 1, 6)


func test_total_is_the_sum_of_values() -> void:
	var roller := DiceRoller.new(_seeded(1))
	var values := roller.roll(4)
	var sum := 0
	for v in values:
		sum += v
	assert_eq(roller.total(), sum)


func test_count_reflects_last_roll() -> void:
	var roller := DiceRoller.new()
	roller.roll(2)
	assert_eq(roller.count(), 2)


func test_has_result_only_after_a_roll() -> void:
	var roller := DiceRoller.new()
	assert_false(roller.has_result())
	roller.roll(2)
	assert_true(roller.has_result())


func test_roll_is_deterministic_for_equal_seeds() -> void:
	var a := DiceRoller.new(_seeded(42)).roll(6)
	var b := DiceRoller.new(_seeded(42)).roll(6)
	assert_eq(a, b)


func test_roll_emits_rolled_signal() -> void:
	var roller := DiceRoller.new()
	watch_signals(roller)
	roller.roll(2)
	assert_signal_emitted(roller, "rolled")


func test_roll_zero_yields_empty_result() -> void:
	var roller := DiceRoller.new()
	assert_eq(roller.roll(0).size(), 0)
	assert_eq(roller.total(), 0)
	assert_false(roller.has_result())


func test_consume_returns_and_clears_the_result() -> void:
	var roller := DiceRoller.new(_seeded(7))
	roller.roll(3)
	var taken := roller.consume()
	assert_eq(taken.size(), 3)
	assert_false(roller.has_result())
	assert_eq(roller.total(), 0)
	assert_eq(roller.values().size(), 0)


func test_consume_emits_consumed_signal() -> void:
	var roller := DiceRoller.new()
	roller.roll(2)
	watch_signals(roller)
	roller.consume()
	assert_signal_emitted(roller, "consumed")


func test_reroll_replaces_one_die_in_range() -> void:
	var roller := DiceRoller.new(_seeded(3))
	roller.roll(2)
	var v := roller.reroll(0)
	assert_between(v, 1, 6, "rerolled die is a valid face")
	assert_eq(roller.values()[0], v, "the recorded result reflects the reroll")


func test_reroll_out_of_range_is_a_noop() -> void:
	var roller := DiceRoller.new(_seeded(3))
	roller.roll(2)
	assert_eq(roller.reroll(5), 0, "out-of-range reroll returns 0")
	assert_eq(roller.values().size(), 2, "result is unchanged")


func test_force_sets_a_die_to_the_given_value() -> void:
	var roller := DiceRoller.new(_seeded(3))
	roller.roll(2)
	assert_eq(roller.force(0, 6), 6)
	assert_eq(roller.values()[0], 6, "the recorded result reflects the forced value")


func test_force_out_of_range_is_a_noop() -> void:
	var roller := DiceRoller.new(_seeded(3))
	roller.roll(2)
	assert_eq(roller.force(5, 6), 0, "out-of-range force returns 0")
	assert_eq(roller.values().size(), 2, "result is unchanged")


func test_force_emits_rolled() -> void:
	var roller := DiceRoller.new(_seeded(3))
	roller.roll(2)
	watch_signals(roller)
	roller.force(0, 6)
	assert_signal_emitted(roller, "rolled")
