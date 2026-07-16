extends GutTest
## Smoke tests for PlayHud — the pieces that don't need a live GamePhase: the action button's
## contextual label/visibility and the "?" rules reference overlay.


func _hud() -> PlayHud:
	var hud := PlayHud.new()
	add_child_autofree(hud)
	return hud


func test_reference_overlay_opens_and_closes() -> void:
	var hud := _hud()
	hud.show_reference()
	hud.show_reference()  # idempotent: a second call while open must not stack backdrops
	hud.hide_reference()
	hud.hide_reference()  # idempotent: closing twice must not error
	pass_test("no error opening/closing the reference overlay, including repeated calls")


func test_end_turn_button_only_shows_while_reserve_is_offered() -> void:
	var hud := _hud()
	hud.set_action(PlayHud.Action.ROLL)
	assert_false(hud.is_end_turn_button_visible(), "no secondary button while just rolling")
	hud.set_action(PlayHud.Action.RESERVE)
	assert_true(hud.is_end_turn_button_visible(), "reserving must stay declinable")
	hud.set_action(PlayHud.Action.END_TURN)
	assert_false(hud.is_end_turn_button_visible(), "hidden again once nothing is reservable")


func test_boost_button_hidden_without_tokens_or_outside_the_usable_window() -> void:
	var hud := _hud()
	hud.set_boost_tokens(2, true)
	assert_true(hud.is_boost_button_visible())
	hud.set_boost_tokens(0, true)
	assert_false(hud.is_boost_button_visible(), "no tokens left")
	hud.set_boost_tokens(2, false)
	assert_false(hud.is_boost_button_visible(), "not the right moment (already walking)")


# --- Minimal keyboard support (task #30) -------------------------------------

func _accept_event() -> InputEvent:
	var e := InputEventAction.new()
	e.action = "ui_accept"
	e.pressed = true
	return e


func _cancel_event() -> InputEvent:
	var e := InputEventAction.new()
	e.action = "ui_cancel"
	e.pressed = true
	return e


func test_enter_triggers_the_primary_action_button() -> void:
	var hud := _hud()
	hud.set_action(PlayHud.Action.ROLL)
	watch_signals(hud)
	hud._unhandled_input(_accept_event())
	assert_signal_emitted(hud, "roll_requested")


func test_enter_does_nothing_while_the_reference_overlay_is_open() -> void:
	var hud := _hud()
	hud.show_reference()
	watch_signals(hud)
	hud._unhandled_input(_accept_event())
	assert_signal_not_emitted(hud, "roll_requested")


func test_enter_does_nothing_while_a_chooser_is_open() -> void:
	var hud := _hud()
	hud.show_chooser("Test ?", [{"text": "OK", "color": UITheme.BLUE}], func(_i: int) -> void: pass)
	watch_signals(hud)
	hud._unhandled_input(_accept_event())
	assert_signal_not_emitted(hud, "roll_requested")


func test_escape_cancels_an_open_chooser_like_the_annuler_button() -> void:
	var hud := _hud()
	var picked := [null]
	hud.show_chooser("Test ?", [{"text": "OK", "color": UITheme.BLUE}], func(i: int) -> void: picked[0] = i)
	hud._unhandled_input(_cancel_event())
	assert_null(hud._chooser, "the chooser is dismissed")
	assert_eq(picked[0], -1, "cancelled exactly like pressing Annuler")


func test_escape_closes_the_reference_overlay() -> void:
	var hud := _hud()
	hud.show_reference()
	hud._unhandled_input(_cancel_event())
	assert_null(hud._reference_panel)
