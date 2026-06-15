extends SceneTree
## Screenshot harness for the PLAY phase. Builds a real auto-assembled board, stands up the actual
## play-phase rendering (camera + light + environment + HexGridView + GameRoot/PlayHud), drives a few
## greedy turns through the real handlers, and saves PNGs. Must run WINDOWED (rendering needs a GPU
## context — headless captures are blank):
##   godot --path . -s res://tools/capture_play.gd -- <out_dir> <seed> <players>
## Defaults: out_dir=captures, seed=4, players=4.

const HEX_SIZE_REF := 1.0  # GameConfig.HEX_SIZE is the source of truth; only used for camera framing


func _initialize() -> void:
	_run()


func _run() -> void:
	# Let the main loop run one frame so the tree is "started"; otherwise nodes added during
	# _initialize get their _ready() deferred and GameRoot.setup would touch a half-built HUD.
	await process_frame
	UITheme.install_fonts()
	var args := _script_args()
	var out_dir: String = args[0] if args.size() > 0 else "captures"
	var seed_val: int = int(args[1]) if args.size() > 1 else 4
	var count: int = int(args[2]) if args.size() > 2 else 4
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir))

	get_root().size = Vector2i(1600, 900)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var built := AutoBoard.build(count, rng)
	if not built["ok"]:
		push_error("capture: board assembly failed")
		quit(1)
		return
	var board: Board = built["board"]
	var players: Array = built["players"]
	var typed_players: Array[Player] = []
	for p in players:
		typed_players.append(p)

	var world := Node3D.new()
	get_root().add_child(world)
	SceneEnvironment.build(world)
	var camera := _build_camera(world)
	var grid := HexGridView.new()
	world.add_child(grid)
	grid.setup(board, typed_players)
	var game_root := GameRoot.new()
	world.add_child(game_root)
	game_root.setup(board, typed_players, camera)
	grid.set_drive_cells(game_root.drive_cells())  # storefront art on the real (random) drives

	await _frames(20)
	await _capture(out_dir, "01_plateau")

	# Roll for the first player: dice + reachable-cell highlights + steps badge appear.
	game_root.hud().roll_requested.emit()
	await _frames(20)
	await _capture(out_dir, "02_apres_lancer")

	# Walk a couple of greedy steps so the pawn is mid-board with the trajectory shown.
	var deliveries := game_root.deliveries()
	for _i in range(3):
		var phase := game_root.phase()
		if phase == null or phase.movement() == null:
			break
		var target = AutoPilot.choose_target(phase, deliveries)
		var next = AutoPilot.step_toward(phase, board, deliveries, target)
		if next == null:
			break
		phase.try_step(next)
		await _frames(8)
	await _capture(out_dir, "03_deplacement")

	# Event-card draw — base rule draws TWO, keep one (animated CardView with the designed 2D face).
	var samples := _load_events(2)
	if not samples.is_empty():
		var choice := EventCardChoice.new()
		world.add_child(choice)
		choice.scale = Vector3.ONE * 8.0
		choice.present(samples, camera, Vector3(camera.global_position.x, 5.0, camera.global_position.z))
		await _frames(48)  # let the deal animation finish and the face SubViewports render
		await _capture(out_dir, "06_evenement")
		choice.queue_free()
		await _frames(2)

		# Card back design (face-down card).
		var back_card := CardView.new()
		world.add_child(back_card)
		back_card.scale = Vector3.ONE * 8.0
		back_card.position = Vector3(camera.global_position.x, 5.0, camera.global_position.z)
		back_card.bind(samples[0], null, CardBackFace.build_texture(back_card))
		back_card.set_face_up(false)
		await _frames(20)
		await _capture(out_dir, "07_dos")
		back_card.queue_free()
		await _frames(2)

	# End-of-game scoreboard (fabricated from the current scores).
	var phase := game_root.phase()
	if phase != null:
		game_root.hud().show_end(phase.scores(), typed_players)
		await _frames(16)
		await _capture(out_dir, "04_fin")

	# Character-select screen (its own opaque backdrop covers the board).
	var chars := _load_characters()
	if not chars.is_empty():
		var select := CharacterSelect.new()
		get_root().add_child(select)
		select.setup(count, chars)
		await _frames(16)
		await _capture(out_dir, "05_personnages")

	await _frames(4)
	quit(0)


func _load_events(count: int) -> Array:
	var result: Array = []
	var dir := DirAccess.open("res://resources/events/")
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres") and result.size() < count:
				result.append(load("res://resources/events/" + file))
	return result


func _load_characters() -> Array:
	var result: Array = []
	var dir := DirAccess.open("res://resources/characters/")
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load("res://resources/characters/" + file))
	return result


func _capture(out_dir: String, name: String) -> void:
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://%s/%s.png" % [out_dir, name])
	img.save_png(path)
	print("captured ", path)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _build_camera(parent: Node3D) -> CameraRig:
	var camera := CameraRig.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.position = Vector3(0, 20, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.current = true
	parent.add_child(camera)
	return camera


func _script_args() -> PackedStringArray:
	var result := PackedStringArray()
	var seen := false
	for a in OS.get_cmdline_user_args():
		result.append(a)
		seen = true
	if seen:
		return result
	# fallback: args after a bare "--"
	var all := OS.get_cmdline_args()
	var idx := all.find("--")
	if idx >= 0 and idx + 1 < all.size():
		for i in range(idx + 1, all.size()):
			result.append(all[i])
	return result
