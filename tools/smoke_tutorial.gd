extends SceneTree
## Headless smoke test for the tutorial entry point: boots the REAL scenes/main.tscn, presses
## "Tutoriel" on the title screen, then drives a full session through the REAL UI signal paths
## (PlayHud.roll_requested, GameRoot._on_cell_clicked) rather than calling GamePhase methods on a
## hand-built GameRoot — catching wiring bugs the isolated GUT unit tests wouldn't see (they
## construct GameRoot themselves; this instantiates the whole composition root as the game really
## does). The event card is resolved directly via GamePhase.apply_event (keeping the first drawn
## card) rather than reverse-engineering the interactive 3D card-choice UI's internals.
## Run: godot --headless --path . -s res://tools/smoke_tutorial.gd
## Exits 0 if the whole session completes and reaches the final "Terminer" beat at 25 points; 1 on
## any error. Note: the final "Terminer" press logs a harmless reload_current_scene() error — this
## harness never registers Main as the tree's official current_scene (only a real project boot does).

const _WALK_SETTLE_SECONDS := 0.5  # _on_cell_clicked's walk is real-time paced; frame counts would race it

var _main: Node3D
var _failed := false


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
	title.tutorial_requested.emit()
	await _frames(2)

	var game_root: GameRoot = _main._game_root
	if game_root == null:
		_fail("Main._game_root was not built by _start_tutorial")
		return
	var overlay := _find_child_of_type(_main, "TutorialOverlay")
	if overlay == null:
		_fail("no TutorialOverlay found after starting the tutorial")
		return
	print("beat: welcome — ", overlay._label.text)

	game_root.hud().roll_requested.emit()
	await _frames(3)
	print("beat: after roll — ", overlay._label.text)
	if game_root.phase().current_subphase() != GamePhase.SubPhase.DEPLACEMENT:
		_fail("rolling didn't enter DEPLACEMENT")
		return

	game_root.phase().reserve_delivery()  # the tutorial's tile is reservable right from the start cell
	print("beat: after reserve — ", overlay._label.text)

	game_root._on_cell_clicked(Vector2i(1, 0))
	await _wait_seconds(_WALK_SETTLE_SECONDS)
	game_root._on_cell_clicked(TutorialScenario.EVENT_CELL)
	await _wait_seconds(_WALK_SETTLE_SECONDS)
	if game_root.phase().current_subphase() == GamePhase.SubPhase.EVENEMENT:
		game_root.phase().apply_event(load("res://resources/events/grand_soleil.tres"))
	print("beat: after event — ", overlay._label.text)

	game_root._on_cell_clicked(Vector2i(3, 0))
	await _wait_seconds(_WALK_SETTLE_SECONDS)
	game_root._on_cell_clicked(TutorialScenario.DRIVE_CELL)
	await _wait_seconds(_WALK_SETTLE_SECONDS)
	game_root._on_cell_clicked(TutorialScenario.RECIPIENT_CELL)
	await _wait_seconds(_WALK_SETTLE_SECONDS)
	print("beat: final — ", overlay._label.text)

	var score := game_root.phase().score_of(game_root.phase().current_player())
	if not overlay._finish_btn.visible or score != 25:
		_fail("expected the final beat + a 25-point score, got score=%d, finish_visible=%s" % [score, overlay._finish_btn.visible])
		return

	if _failed:
		quit(1)
	else:
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


func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _fail(msg: String) -> void:
	_failed = true
	printerr("SMOKE FAIL: ", msg)
