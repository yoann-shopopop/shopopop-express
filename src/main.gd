extends Node3D
## Composition root for the setup phase. Builds the top-down view, asks the player count, then wires
## the distribution, the turn-by-turn placement phase, the board view, the pointer controller and UI.

const PATTERNS_DIR := "res://resources/blocks/patterns/"
const CHARACTERS_DIR := "res://resources/characters/"
const BRIDGE_PATH := "res://resources/blocks/bridge.tres"
const ENSEIGNES_DIR := "res://resources/enseignes/"
const DESTINATAIRES_DIR := "res://resources/destinataires/"
const EVENTS_DIR := "res://resources/events/"

var board: Board
var phase: SetupPhase
var controller: PlacementController
var grid_view: HexGridView

var _camera: CameraRig
var _ghost: BlockGhost
var _ui: PlacementUI
var _zoom_controls: ZoomControls
var _library: Array[BlockDefinition] = []
var _characters: Array[CharacterDefinition] = []
var _bridge: BlockDefinition
var _players: Array[Player] = []
var _game_root: GameRoot
var _initial_piece_counts: Dictionary = {}  # Player -> initial tile count, for the "Tour X/Y" header


func _ready() -> void:
	UITheme.install_fonts()  # app-wide default font (Nunito); titles opt into the display font
	add_child(GameSettings.new())  # loads/applies user://settings.cfg — before AudioManager routes to its buses
	add_child(AudioManager.new())  # SFX + looping ambient music (static helpers thereafter)
	_library = _load_library()
	_characters = _load_characters()
	_bridge = load(BRIDGE_PATH)
	_camera = _build_camera()
	SceneEnvironment.build(self)
	_zoom_controls = ZoomControls.new()
	add_child(_zoom_controls)
	_zoom_controls.zoom_in_requested.connect(_camera.zoom_in)
	_zoom_controls.zoom_out_requested.connect(_camera.zoom_out)
	_ui = PlacementUI.new()
	add_child(_ui)
	_ui.player_count_chosen.connect(_on_player_count_chosen)

	# Opening title screen (above everything); dismissing it reveals the player-count chooser.
	var title := TitleScreen.new()
	add_child(title)
	title.start_requested.connect(func() -> void: title.queue_free())
	title.tutorial_requested.connect(func() -> void:
		title.queue_free()
		_start_tutorial())
	title.tournee_requested.connect(func() -> void:
		title.queue_free()
		_start_tournee())


## Starts a game with [param count] players. [param rng_seed] >= 0 makes the draw deterministic.
## [param chosen] holds one character per seat (from the character-select screen); empty = random deal.
## [param is_ai] marks which seats GameRoot auto-plays (see AutoPilot); empty = every seat is Humain.
func start_game(
	count: int, rng_seed: int = -1, chosen: Array[CharacterDefinition] = [], is_ai: Array = []
) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	_players = SetupDistributor.build_players(count, _library, _bridge, rng, _characters, chosen)
	for i in _players.size():
		if i < is_ai.size():
			_players[i].is_ai = is_ai[i]
	_initial_piece_counts.clear()
	for p in _players:
		_initial_piece_counts[p] = p.pieces.size()
	_ui.begin_game()

	board = Board.new()
	phase = SetupPhase.new(_players, board)

	grid_view = HexGridView.new()
	add_child(grid_view)
	grid_view.setup(board, _players)

	_ghost = BlockGhost.new()
	add_child(_ghost)

	controller = PlacementController.new()
	add_child(controller)
	controller.setup(_camera, board, _ghost, phase)

	phase.turn_changed.connect(_on_turn_changed)
	phase.turn_state_changed.connect(_on_turn_changed)
	phase.setup_finished.connect(_on_setup_finished)
	_ui.piece_drag_started.connect(controller.begin_drag)
	_ui.bridge_drag_started.connect(controller.begin_bridge_drag)
	_ui.finish_requested.connect(_on_finish_requested)
	_ui.rotate_requested.connect(controller.rotate_current)
	_ui.rotate_left_requested.connect(func() -> void: controller.rotate_active(-1))
	_ui.rotate_right_requested.connect(func() -> void: controller.rotate_active(1))
	_ui.remove_requested.connect(controller.remove_active)
	controller.controls_changed.connect(_ui.update_controls)
	controller.drag_changed.connect(_ui.set_dragging)
	_refresh_ui()


func _on_player_count_chosen(count: int) -> void:
	if _characters.is_empty():
		start_game(count)  # no character data: skip the draft
		return
	var select := CharacterSelect.new()
	add_child(select)
	select.setup(count, _characters)
	select.characters_chosen.connect(func(chosen: Array, is_ai: Array) -> void:
		var typed: Array[CharacterDefinition] = []
		for c in chosen:
			typed.append(c)
		start_game(count, -1, typed, is_ai))


func _on_turn_changed(_player: Player) -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	var player := phase.current_player()
	var total: int = _initial_piece_counts.get(player, player.pieces.size())
	var index := PlacementUI.compute_turn_index(total, player.pieces.size(), phase.block_placed_this_turn())
	_ui.set_current_player(player, phase.block_placed_this_turn(), index, total)
	_ui.set_dragging(false)


func _on_finish_requested() -> void:
	phase.finish_turn()


func _on_setup_finished() -> void:
	# Hand over from setup to the play phase: drop the placement UI/controller and start GameRoot,
	# which owns the moving pawns, dice, movement input and the in-game UI.
	_ui.queue_free()
	controller.queue_free()
	_zoom_controls.hide()  # PlayHud owns zoom controls in the title bar during play
	_game_root = GameRoot.new()
	add_child(_game_root)
	_game_root.setup(board, _players, _camera)
	# The deliveries (random, possibly cross-tile) now exist: tell the board view where the drives are.
	grid_view.set_drive_cells(_game_root.drive_cells())
	# Event cells are consumed on trigger and re-armed each round: mirror their state on the board art.
	_game_root.phase().event_cell_spent.connect(_on_event_cells_changed)
	_game_root.phase().event_cells_rearmed.connect(_on_event_cells_changed)


## The guided first-time session: skips the placement phase entirely for TutorialScenario's
## hand-authored, deterministic mini-board (a single tile, one mono-tile delivery worth the full 25),
## wired straight into GameRoot via its deterministic-session overrides (forced_deliveries/
## forced_event_order — see [method GameRoot.setup]). A [TutorialDirector] then narrates the real,
## unlocked play through a [TutorialOverlay] bubble; "Terminer" reloads back to the title screen.
func _start_tutorial() -> void:
	_ui.queue_free()
	_zoom_controls.hide()  # PlayHud owns zoom controls in the title bar during play

	board = TutorialScenario.build_board(PlayerColor.Kind.BLUE)
	var player := TutorialScenario.build_player(PlayerColor.Kind.BLUE, board)
	_players = [player]

	grid_view = HexGridView.new()
	add_child(grid_view)
	grid_view.setup(board, _players)

	_game_root = GameRoot.new()
	add_child(_game_root)
	var delivery := TutorialScenario.build_delivery(board)
	var event_order := TutorialScenario.build_event_order()
	_game_root.setup(board, _players, _camera, null, [delivery] as Array[Delivery], null, event_order)
	grid_view.set_drive_cells(_game_root.drive_cells())
	_game_root.phase().event_cell_spent.connect(_on_event_cells_changed)
	_game_root.phase().event_cells_rearmed.connect(_on_event_cells_changed)

	var overlay := TutorialOverlay.new()
	add_child(overlay)
	var director := TutorialDirector.new()
	add_child(director)
	director.start(_game_root.phase(), overlay)
	director.finished.connect(func() -> void: get_tree().reload_current_scene())


## The solo score-attack mode: skips the placement phase entirely via [AutoBoard] ("tournée express" —
## a full board auto-assembled the same legal way a human would, instantly) for a single player, then
## wires [GameRoot] as usual and layers [TourneeSession] on top (16-round clock, chaining bonus, the
## "score du collègue" ghost computed on the SAME starting deliveries before the session begins).
func _start_tournee() -> void:
	_ui.queue_free()
	_zoom_controls.hide()  # PlayHud owns zoom controls in the title bar during play

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var built := AutoBoard.build(1, rng)
	board = built["board"]
	_players = []
	for p in built["players"]:
		_players.append(p)

	grid_view = HexGridView.new()
	add_child(grid_view)
	grid_view.setup(board, _players)

	_game_root = GameRoot.new()
	add_child(_game_root)
	_game_root.setup(board, _players, _camera, rng, [], null, [], true)
	grid_view.set_drive_cells(_game_root.drive_cells())
	_game_root.phase().event_cell_spent.connect(_on_event_cells_changed)
	_game_root.phase().event_cells_rearmed.connect(_on_event_cells_changed)

	var ghost_rng := RandomNumberGenerator.new()
	ghost_rng.randomize()
	var ghost_score := TourneeSession.compute_ghost_score(
		board, _players[0], _game_root.deliveries(),
		_load_enseignes(), _load_destinataires(), _load_events(), ghost_rng)

	var session := TourneeSession.new()
	add_child(session)
	session.start(_game_root.phase(), ghost_score)
	_game_root.set_tournee_session(session)


func _load_enseignes() -> Array[EnseigneDefinition]:
	var result: Array[EnseigneDefinition] = []
	var dir := DirAccess.open(ENSEIGNES_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(ENSEIGNES_DIR + file))
	return result


func _load_destinataires() -> Array[DestinataireDefinition]:
	var result: Array[DestinataireDefinition] = []
	var dir := DirAccess.open(DESTINATAIRES_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(DESTINATAIRES_DIR + file))
	return result


func _load_events() -> Array[CardDefinition]:
	var result: Array[CardDefinition] = []
	var dir := DirAccess.open(EVENTS_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(EVENTS_DIR + file))
	return result


func _on_event_cells_changed(_cell = null) -> void:
	grid_view.set_spent_event_cells(_game_root.phase().spent_event_cells())


# --- Static library ---------------------------------------------------------

func _load_library() -> Array[BlockDefinition]:
	var result: Array[BlockDefinition] = []
	var dir := DirAccess.open(PATTERNS_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(PATTERNS_DIR + file))
	return result


func _load_characters() -> Array[CharacterDefinition]:
	var result: Array[CharacterDefinition] = []
	var dir := DirAccess.open(CHARACTERS_DIR)
	if dir:
		for file in dir.get_files():
			if file.ends_with(".tres"):
				result.append(load(CHARACTERS_DIR + file))
	return result


# --- Scene scaffolding ------------------------------------------------------

func _build_camera() -> CameraRig:
	var camera := CameraRig.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0  # ortho vertical span in world units (~2.5 tiles tall); lower = zoomed in
	camera.position = Vector3(0, 20, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.current = true
	add_child(camera)
	return camera


