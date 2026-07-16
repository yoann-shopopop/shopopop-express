extends SceneTree
## Headless smoke test for the "La Tournée" solo entry point: boots the REAL scenes/main.tscn,
## presses "La Tournée (solo)" on the title screen, and checks the wiring Main._start_tournee is
## responsible for (AutoBoard-built solo board, GameRoot.set_tournee_session, the clock label) —
## the same class of wiring bug the AI re-entrancy fix (GameRoot._play_ai_turn) was caught by.
## The 16-round playthrough itself is driven by marking the lone seat AI and reusing the already
## heavily-tested _play_ai_turn loop (manual click-to-walk is exercised by tools/smoke_tutorial.gd
## instead — re-testing it here would duplicate coverage without touching new code).
## Run: godot --headless --path . -s res://tools/smoke_tournee.gd
## Exits 0 once TourneeSession.session_finished fires with a positive score; 1 on any error/timeout.

var _main: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	UITheme.install_fonts()
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await process_frame

	var title := _find_child_of_type(_main, "TitleScreen")
	if title == null:
		_fail("no TitleScreen found at boot")
		return
	title.tournee_requested.emit()
	await _frames(2)

	var game_root: GameRoot = _main._game_root
	if game_root == null:
		_fail("Main._game_root was not built by _start_tournee")
		return
	var session: TourneeSession = game_root._tournee_session
	if session == null:
		_fail("no TourneeSession wired by _start_tournee")
		return
	var clock_text: String = game_root.hud()._round_label.text
	print("clock at start: ", clock_text)
	if clock_text != "8h00":
		_fail("expected the clock to read 8h00 at round 1, got %s" % clock_text)
		return
	if game_root.deliveries().is_empty():
		_fail("no deliveries built for the solo board")
		return
	print("ghost score to beat: ", session.ghost_score())

	game_root._players[0].is_ai = true
	game_root._play_ai_turn(game_root._players[0])
	# A direct await, not a poll loop over a bool flipped inside session_finished.connect(func...):
	# GDScript lambdas capture outer locals BY VALUE, so a closure assigning to an outer `finished`/
	# `result` never writes back — the signal fires (verified separately), but a polling loop watching
	# those locals never observes it and spins to the ceiling. Awaiting the signal itself sidesteps that.
	var result: Dictionary = await session.session_finished
	print("result: ", result)
	if result.get("score", 0) <= 0:
		_fail("expected a positive score from a full playthrough, got %s" % result)
		return

	print("SMOKE OK")
	quit(0)


func _find_child_of_type(node: Node, class_name_str: String) -> Node:
	for child in node.get_children():
		var script: Script = child.get_script()
		if script != null and script.get_global_name() == class_name_str:
			return child
		var found := _find_child_of_type(child, class_name_str)
		if found != null:
			return found
	return null


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _fail(msg: String) -> void:
	printerr("SMOKE FAIL: ", msg)
	quit(1)
