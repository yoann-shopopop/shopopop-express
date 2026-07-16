extends SceneTree
## Headless smoke test for the English locale: forces "en" BEFORE booting the REAL scenes/main.tscn
## (simulating what task #26's language setting will eventually do), then drives the tutorial exactly
## like tools/smoke_tutorial.gd and prints every piece of user-facing text encountered — title screen,
## tutorial bubbles, HUD labels, the reference overlay — so a human can read through and confirm
## nothing is still in French (proper nouns — character/enseigne/destinataire names, power names like
## "Bonne Marcheuse" — are intentionally kept in French; see CLAUDE.md's i18n section).
## Run: godot --headless --path . -s res://tools/smoke_i18n_en.gd

const _WALK_SETTLE_SECONDS := 0.5

var _main: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	UITheme.install_fonts()
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await process_frame
	# Main._ready() just created GameSettings, which loads user://settings.cfg and applies its own
	# locale (defaults to "fr" absent a real file) — that happens AFTER any pre-boot override, so
	# forcing English has to happen here instead, simulating "the player already chose English"
	# without writing to the real settings file (nothing in this smoke test calls a GameSettings
	# setter, so user://settings.cfg is only ever read here, never written).
	TranslationServer.set_locale("en")

	# The boot-time TitleScreen was already built in _ready(), before the override above — tr() bakes
	# text in at construction, it does not react to a later locale change. Check English rendering on
	# a FRESH standalone instance instead (built after the override), then discard it.
	var scratch_title := TitleScreen.new()
	get_root().add_child(scratch_title)
	await process_frame
	_print_title_screen_buttons(scratch_title)
	scratch_title.queue_free()
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
	print("HUD action button: ", game_root.hud()._action_btn.text)
	print("HUD round label: ", game_root.hud()._round_label.text)

	game_root.phase().reserve_delivery()
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

	game_root.hud().show_reference()
	_print_reference_overlay(game_root.hud())
	game_root.hud().hide_reference()

	print("SMOKE OK")
	quit(0)


func _print_title_screen_buttons(title: Node) -> void:
	for child in _all_descendants(title):
		if child is Button:
			print("title screen button: ", (child as Button).text)


func _print_reference_overlay(hud: PlayHud) -> void:
	print("--- reference overlay (en) ---")
	for child in _all_descendants(hud._reference_panel):
		if child is Label:
			print("  ", (child as Label).text)


func _all_descendants(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


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
	printerr("SMOKE FAIL: ", msg)
	quit(1)
