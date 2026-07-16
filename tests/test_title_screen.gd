extends GutTest
## Tests for TitleScreen — Enter/Space (task #30) triggers the same "Jouer" action as the button.


func _accept_event() -> InputEvent:
	var e := InputEventAction.new()
	e.action = "ui_accept"
	e.pressed = true
	return e


func test_enter_triggers_start_requested() -> void:
	var title := TitleScreen.new()
	add_child_autofree(title)
	watch_signals(title)
	title._unhandled_input(_accept_event())
	assert_signal_emitted(title, "start_requested")
