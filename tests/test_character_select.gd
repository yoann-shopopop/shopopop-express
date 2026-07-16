extends GutTest
## Tests for CharacterSelect's per-seat "IA" toggle (Coup de pouce for solo play): the toggle applies
## to the CURRENT seat only, resets to Humain once that seat is picked, and the emitted arrays line up.


func _characters(n: int) -> Array:
	var result: Array = []
	for i in n:
		var c := CharacterDefinition.new()
		c.id = StringName("c%d" % i)
		result.append(c)
	return result


func _select(count: int) -> CharacterSelect:
	var select := CharacterSelect.new()
	add_child_autofree(select)
	select.setup(count, _characters(4))
	return select


func test_default_pick_is_humain() -> void:
	var select := _select(2)
	watch_signals(select)
	select._pick(0)
	select._pick(1)
	assert_signal_emitted_with_parameters(select, "characters_chosen", [select._chosen, [false, false]])


func test_toggling_ai_before_a_pick_marks_only_that_seat() -> void:
	var select := _select(2)
	select._seat_ai_toggle = true  # seat 0: turn on IA before picking
	select._pick(0)
	assert_eq(select._is_ai, [true], "seat 0 marked IA")
	assert_false(select._seat_ai_toggle, "the toggle resets for the next seat")
	select._pick(1)  # seat 1: left untouched, defaults to Humain
	assert_eq(select._is_ai, [true, false])


func test_fill_random_leaves_remaining_seats_humain() -> void:
	var select := _select(3)
	select._seat_ai_toggle = true
	select._pick(0)  # seat 0: IA
	watch_signals(select)
	select._fill_random()  # seats 1-2: bulk-filled, always Humain
	assert_eq(select._is_ai, [true, false, false])
	assert_signal_emitted_with_parameters(select, "characters_chosen", [select._chosen, [true, false, false]])
