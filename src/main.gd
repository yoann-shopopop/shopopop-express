extends Node3D
## Composition root for the setup phase. Builds the top-down view, asks the player count, then wires
## the distribution, the turn-by-turn placement phase, the board view, the pointer controller and UI.

const PATTERNS_DIR := "res://resources/blocks/patterns/"
const CHARACTERS_DIR := "res://resources/characters/"
const BRIDGE_PATH := "res://resources/blocks/bridge.tres"

var board: Board
var phase: SetupPhase
var controller: PlacementController
var grid_view: HexGridView

var _camera: CameraRig
var _ghost: BlockGhost
var _bridge_ghost: BlockGhost
var _ui: PlacementUI
var _zoom_controls: ZoomControls
var _library: Array[BlockDefinition] = []
var _characters: Array[CharacterDefinition] = []
var _bridge: BlockDefinition
var _players: Array[Player] = []
var _game_root: GameRoot


func _ready() -> void:
	_library = _load_library()
	_characters = _load_characters()
	_bridge = load(BRIDGE_PATH)
	_camera = _build_camera()
	_build_light()
	_build_environment()
	_zoom_controls = ZoomControls.new()
	add_child(_zoom_controls)
	_zoom_controls.zoom_in_requested.connect(_camera.zoom_in)
	_zoom_controls.zoom_out_requested.connect(_camera.zoom_out)
	_ui = PlacementUI.new()
	add_child(_ui)
	_ui.player_count_chosen.connect(_on_player_count_chosen)


## Starts a game with [param count] players. [param rng_seed] >= 0 makes the draw deterministic.
func start_game(count: int, rng_seed: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	_players = SetupDistributor.build_players(count, _library, _bridge, rng, _characters)
	_ui.begin_game()

	board = Board.new()
	phase = SetupPhase.new(_players, board)

	grid_view = HexGridView.new()
	add_child(grid_view)
	grid_view.setup(board, _players)

	_ghost = BlockGhost.new()
	add_child(_ghost)
	_bridge_ghost = BlockGhost.new()
	add_child(_bridge_ghost)

	controller = PlacementController.new()
	add_child(controller)
	controller.setup(_camera, board, _ghost, _bridge_ghost, phase)

	phase.turn_changed.connect(_on_turn_changed)
	phase.setup_finished.connect(_on_setup_finished)
	_ui.piece_drag_started.connect(controller.begin_drag)
	_ui.bridge_drag_started.connect(controller.begin_bridge_drag)
	_ui.pass_requested.connect(_on_pass_requested)
	_ui.rotate_requested.connect(controller.rotate_current)
	_ui.set_current_player(phase.current_player())


func _on_player_count_chosen(count: int) -> void:
	start_game(count)


func _on_turn_changed(player: Player) -> void:
	_ui.set_current_player(player)


func _on_pass_requested() -> void:
	phase.pass_turn()


func _on_setup_finished() -> void:
	# Hand over from setup to the play phase: drop the placement UI/controller and start GameRoot,
	# which owns the moving pawns, dice, movement input and the in-game UI.
	_ui.queue_free()
	controller.queue_free()
	_game_root = GameRoot.new()
	add_child(_game_root)
	_game_root.setup(board, _players, _camera)


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


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -40, 0)
	light.shadow_enabled = true
	add_child(light)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b2330")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8090a0")
	env.ambient_light_energy = 0.6
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)
